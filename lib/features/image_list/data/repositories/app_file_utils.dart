import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/image_extensions.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/caption_data.dart';
import '../../../../core/models/caption_database.dart';
import '../../../../core/models/caption_entry.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../caption_session/caption_session.dart';

/// A utility class for file-related operations in the application.
///
/// Also serves as the data-layer implementation of the domain session's
/// [CaptionFileStore] port.
class AppFileUtils implements CaptionFileStore {
  AppFileUtils({CacheService? cacheService})
    : _cacheService = cacheService ?? const CacheService();

  final CacheService _cacheService;

  static final Logger _logger = Logger('AppFileUtils');

  @override
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath) async {
    try {
      final Directory dir = await _managePersistentPermission(folderPath);
      final Either<Failure, CaptionDatabase> dbResult = await readDb(
        folderPath,
      );
      // A corrupt/unreadable db.json must not fail the whole folder load:
      // images still enumerate (with empty captions) and the db failure is
      // surfaced so the UI can show its warning banner. Propagate the Left
      // as data instead of unwrapping it — never `!` a Left.
      late final CaptionDatabase db;
      Failure? dbFailure;
      dbResult.fold((Failure f) {
        dbFailure = f;
        db = CaptionDatabase(
          categories: <String>['default'],
          activeCategory: 'default',
          images: <CaptionData>[],
        );
      }, (CaptionDatabase d) => db = d);
      bool dbWasModified = false;

      final List<FileSystemEntity> files = dir.listSync();
      final List<AppImage> images = <AppImage>[];
      final List<String> foundFilenames = <String>[];

      // Filename-keyed index of db entries so per-file lookups stay O(1) —
      // first occurrence wins, matching the previous firstWhere semantics.
      final Map<String, CaptionData> dbByName = <String, CaptionData>{};
      for (final CaptionData d in db.images) {
        dbByName.putIfAbsent(d.filename, () => d);
      }

      for (final FileSystemEntity file in files) {
        if (file is File) {
          if (isSupportedImageFile(file.path)) {
            final String filename = p.basename(file.path);
            foundFilenames.add(filename);

            final CaptionData? existingData = dbByName[filename];
            final CaptionData captionData =
                existingData ??
                CaptionData(
                  id: const Uuid().v4(),
                  filename: filename,
                  captions: <String, CaptionEntry>{},
                );
            if (existingData == null) {
              dbWasModified = true;
            }

            final CaptionData hydratedCaptionData =
                await _hydrateCaptionDataFromLegacyTxt(
                  captionData: captionData,
                  folderPath: folderPath,
                );

            if (!identical(hydratedCaptionData, captionData)) {
              dbWasModified = true;
            }

            if (existingData == null) {
              db.images.add(hydratedCaptionData);
              dbByName[filename] = hydratedCaptionData;
            } else if (!identical(hydratedCaptionData, existingData)) {
              db.images[db.images.indexOf(existingData)] = hydratedCaptionData;
              dbByName[filename] = hydratedCaptionData;
            }

            images.add(
              AppImage(
                id: hydratedCaptionData.id,
                image: file,
                captions: hydratedCaptionData.captions,
                size: file.lengthSync(),
                lastModified: hydratedCaptionData.lastModified,
                tags: hydratedCaptionData.tags,
              ),
            );
          }
        }
      }

      final Set<String> foundFilenameSet = foundFilenames.toSet();
      final int dbCountBeforeRemove = db.images.length;
      db.images.removeWhere(
        (CaptionData d) => !foundFilenameSet.contains(d.filename),
      );
      final bool removedItems = db.images.length != dbCountBeforeRemove;

      // Never rewrite db.json when it could not be read — writing an empty
      // database over a corrupt (possibly recoverable) file would destroy it.
      if ((dbWasModified || removedItems) && dbFailure == null) {
        await writeDb(folderPath, db);
      }

      images.sort(
        (AppImage a, AppImage b) => compareNatural(a.image.path, b.image.path),
      );
      return Right<
        Failure,
        ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
      >((images: images, db: db, dbFailure: dbFailure));
    } catch (e, st) {
      return Left<
        Failure,
        ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
      >(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'AppFileUtils.onFolderPicked',
        ),
      );
    }
  }

  Future<String?> _readLegacyCaptionText({
    required String folderPath,
    required String filename,
  }) async {
    final File txtFile = File(
      p.join(folderPath, p.setExtension(filename, '.txt')),
    );

    try {
      return await txtFile.readAsString();
    } on FileSystemException {
      // Missing or unreadable sidecar file — nothing to hydrate.
      return null;
    }
  }

  bool _hasAnyNonEmptyCaption(Map<String, CaptionEntry> captions) {
    return captions.values.any((CaptionEntry entry) => entry.text.isNotEmpty);
  }

  Future<CaptionData> _hydrateCaptionDataFromLegacyTxt({
    required CaptionData captionData,
    required String folderPath,
  }) async {
    if (_hasAnyNonEmptyCaption(captionData.captions)) {
      return captionData;
    }

    final String? legacyCaptionText = await _readLegacyCaptionText(
      folderPath: folderPath,
      filename: captionData.filename,
    );

    if (legacyCaptionText == null) {
      return captionData;
    }

    return CaptionData(
      id: captionData.id,
      filename: captionData.filename,
      captions: <String, CaptionEntry>{
        ...captionData.captions,
        'default': CaptionEntry(
          text: legacyCaptionText,
          model: captionData.captions['default']?.model,
          timestamp: captionData.captions['default']?.timestamp,
          isEdited: captionData.captions['default']?.isEdited ?? false,
        ),
      },
      lastModified: captionData.lastModified,
      tags: captionData.tags,
    );
  }

  File _getDbPath(String folderPath) {
    return File(p.join(folderPath, 'db.json'));
  }

  Future<CaptionDatabase> _migrateV1ToV2(
    Map<String, dynamic> oldJson,
    String folderPath,
  ) async {
    final List<dynamic> oldImages = oldJson['images'] as List<dynamic>;
    final List<CaptionData> migratedImages = <CaptionData>[];

    for (final dynamic img in oldImages) {
      final String filename =
          (img as Map<String, dynamic>)['filename'] as String;
      final String id = img['id'] as String;

      final String captionText =
          await _readLegacyCaptionText(
            folderPath: folderPath,
            filename: filename,
          ) ??
          '';

      migratedImages.add(
        CaptionData(
          id: id,
          filename: filename,
          captions: <String, CaptionEntry>{
            'default': CaptionEntry(
              text: captionText,
              model: img['captionModel'] as String?,
              timestamp: img['captionTimestamp'] != null
                  ? DateTime.parse(img['captionTimestamp'] as String)
                  : null,
            ),
          },
          lastModified: img['lastModified'] != null
              ? DateTime.parse(img['lastModified'] as String)
              : null,
        ),
      );
    }

    return CaptionDatabase(
      categories: <String>['default'],
      activeCategory: 'default',
      images: migratedImages,
    );
  }

  CaptionDatabase _migrateV2ToV3(Map<String, dynamic> oldJson) {
    final List<dynamic> oldImages = oldJson['images'] as List<dynamic>;
    for (final dynamic img in oldImages) {
      final Map<String, dynamic> map = img as Map<String, dynamic>;
      if (!map.containsKey('tags')) {
        map['tags'] = <String>[];
      }
    }
    return CaptionDatabase.fromJson(<String, dynamic>{
      ...oldJson,
      'version': 3,
    });
  }

  CaptionDatabase _migrateV3ToV4(Map<String, dynamic> oldJson) {
    return CaptionDatabase.fromJson(<String, dynamic>{
      ...oldJson,
      'version': 4,
      'categoryFormats': <String, String>{},
    });
  }

  @override
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath) async {
    final File dbFile = _getDbPath(folderPath);
    if (await dbFile.exists()) {
      try {
        final String content = await dbFile.readAsString();
        final Map<String, dynamic> json =
            jsonDecode(content) as Map<String, dynamic>;

        // Check version for migration
        if (!json.containsKey('version')) {
          // Migrate from v1 to v2
          final CaptionDatabase migrated = await _migrateV1ToV2(
            json,
            folderPath,
          );
          await writeDb(folderPath, migrated);
          return Right<Failure, CaptionDatabase>(migrated);
        }

        final int version = (json['version'] as num?)?.toInt() ?? 1;
        if (version < 3) {
          final CaptionDatabase migrated = _migrateV2ToV3(json);
          await writeDb(folderPath, migrated);
          return Right<Failure, CaptionDatabase>(migrated);
        }
        if (version < 4) {
          final CaptionDatabase migrated = _migrateV3ToV4(json);
          await writeDb(folderPath, migrated);
          return Right<Failure, CaptionDatabase>(migrated);
        }
        return Right<Failure, CaptionDatabase>(CaptionDatabase.fromJson(json));
      } catch (e, st) {
        // A db.json we cannot parse or migrate is a real failure: surfacing
        // it lets the UI warn instead of silently loading an empty library.
        return Left<Failure, CaptionDatabase>(
          mapExceptionToFailure(e, stackTrace: st, tag: 'AppFileUtils.readDb'),
        );
      }
    }

    // New folder - create with default structure
    return Right<Failure, CaptionDatabase>(
      CaptionDatabase(
        categories: <String>['default'],
        activeCategory: 'default',
        images: <CaptionData>[],
      ),
    );
  }

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {
    final File dbFile = _getDbPath(folderPath);
    final String content = jsonEncode(db.toJson());
    await dbFile.writeAsString(content);
  }

  Future<void> updateDbForRename(
    Map<String, String> oldNameToNewName,
    String folderPath,
  ) async {
    final Either<Failure, CaptionDatabase> dbResult = await readDb(folderPath);
    final CaptionDatabase? db = dbResult.getRight().toNullable();
    if (db == null) {
      // Captions were not loaded for this folder; renaming entries would
      // silently drop them. Log and skip the db rewrite.
      _logger.severe(
        'updateDbForRename: db.json unreadable in $folderPath: '
        '${dbResult.getLeft().toNullable()}',
      );
      return;
    }

    // Snapshot current filenames before mutating: writing newName in place
    // while still resolving by filename aliases entries when a target collides
    // with a pending source name (e.g. 00->01, 01->02, ...).
    final Map<String, CaptionData> byName = <String, CaptionData>{
      for (final CaptionData d in db.images) d.filename: d,
    };

    for (final MapEntry<String, String> entry in oldNameToNewName.entries) {
      final CaptionData? data = byName[entry.key];
      if (data != null) {
        data.filename = entry.value;
      }
    }

    await writeDb(folderPath, db);
  }

  Future<Either<Failure, void>> exportAsArchive(
    String folderPath,
    List<AppImage> images,
    String category,
  ) async {
    try {
      final String? downloadsPath = await getDownloadsDirectory().then(
        (Directory? dir) => dir?.path,
      );
      final String baseFileName = p.basename(folderPath);
      final String fileName = category == 'default'
          ? '$baseFileName.zip'
          : '$baseFileName-$category.zip';

      // ponytail: build zip to temp file first; file_picker v12 saveFile
      // requires bytes upfront and writes them itself (no path-only mode).
      final String tempPath = p.join(Directory.systemTemp.path, fileName);
      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(tempPath);

      // Add images and their captions
      for (final AppImage image in images) {
        await encoder.addFile(image.image);

        final CaptionEntry? captionEntry = image.captions[category];
        if (captionEntry != null && captionEntry.text.isNotEmpty) {
          final bool isJson = IdeogramCaption.isIdeogramJson(captionEntry.text);
          final List<int> captionBytes = utf8.encode(captionEntry.text);
          final ArchiveFile archiveFile = ArchiveFile(
            p.setExtension(
              p.basename(image.image.path),
              isJson ? '.json' : '.txt',
            ),
            captionBytes.length,
            captionBytes,
          );
          encoder.addArchiveFile(archiveFile);
        }
      }

      // Close the zip file first to finalize the archive
      encoder.close();

      final Uint8List zipBytes = await File(tempPath).readAsBytes();
      await File(tempPath).delete();

      final Uri? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Please select an output file',
        fileName: fileName,
        initialDirectory: downloadsPath,
        bytes: zipBytes,
      );
      if (outputFile == null) {
        _logger.fine('exportAsArchive: user cancelled the save dialog');
      }
      // file_picker v13 writes `bytes` to the chosen path itself; the
      // returned Uri is informational.
      return const Right<Failure, void>(null);
    } catch (e, st) {
      return Left<Failure, void>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'AppFileUtils.exportAsArchive',
        ),
      );
    }
  }

  @override
  Future<void> writeCaptionFiles(
    String folderPath,
    List<AppImage> images,
    String category,
    String format,
  ) async {
    for (final AppImage image in images) {
      final CaptionEntry? entry = image.captions[category];
      if (entry == null || entry.text.isEmpty) continue;

      final String ext = format == 'json' ? '.json' : '.txt';
      final String filePath = p.join(
        folderPath,
        '${p.basenameWithoutExtension(image.image.path)}$ext',
      );
      await File(filePath).writeAsString(entry.text);
    }
  }

  @override
  Future<void> removeCaptionFiles(
    String folderPath,
    List<AppImage> images,
  ) async {
    for (final AppImage image in images) {
      final String base = p.join(
        folderPath,
        p.basenameWithoutExtension(image.image.path),
      );
      final File txtFile = File('$base.txt');
      if (await txtFile.exists()) await txtFile.delete();
      final File jsonFile = File('$base.json');
      if (await jsonFile.exists()) await jsonFile.delete();
    }
  }

  @override
  Future<void> removeImage(File imageFile) async {
    await imageFile.delete();
    final String txtPath = p.setExtension(imageFile.path, '.txt');
    final File txtFile = File(txtPath);
    if (await txtFile.exists()) {
      await txtFile.delete();
    }
  }

  Future<Directory> _managePersistentPermission(String folderPath) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Directory(folderPath);
    }
    if (!Platform.isMacOS) return Directory(folderPath);
    String? bookmark = await _cacheService.loadMacosBookmark(
      folderPath: folderPath,
    );
    final SecureBookmarks secureBookmarks = SecureBookmarks();
    if (bookmark == null) {
      bookmark = await secureBookmarks.bookmark(Directory(folderPath));
      await _cacheService.saveMacosBookmark(
        bookmark: bookmark,
        folderPath: folderPath,
      );
      return Directory(folderPath);
    } else {
      try {
        final FileSystemEntity resolvedEntity = await secureBookmarks
            .resolveBookmark(bookmark);
        // Start accessing the security scoped resource
        await secureBookmarks.startAccessingSecurityScopedResource(
          resolvedEntity,
        );
        // Return a Directory object using the resolved path
        return Directory(resolvedEntity.path);
      } catch (e) {
        // If bookmark resolution fails (folder removed/moved), clear the bookmark
        await _cacheService.clearMacosBookmark(folderPath: folderPath);
        await _cacheService.clearFolderPath();
        rethrow;
      }
    }
  }

  @override
  Future<AppImage> duplicateImage(AppImage originalImage) async {
    final String originalPath = originalImage.image.path;
    final String directory = p.dirname(originalPath);
    final String basenameWithoutExtension = p.basenameWithoutExtension(
      originalPath,
    );
    final String extension = p.extension(originalPath);

    // Generate a unique filename by adding _copy suffix
    String newBasename = '${basenameWithoutExtension}_copy$extension';
    String newPath = p.join(directory, newBasename);

    // If file exists, append a number
    int counter = 1;
    while (await File(newPath).exists()) {
      newBasename = '${basenameWithoutExtension}_copy$counter$extension';
      newPath = p.join(directory, newBasename);
      counter++;
    }

    // Copy the image file
    await originalImage.image.copy(newPath);

    // Note: Captions are now in db.json, no need to copy .txt files

    // Return the new AppImage with a new ID
    return AppImage(
      id: const Uuid().v4(),
      image: File(newPath),
      captions: originalImage.captions,
      size: await File(newPath).length(),
      captionModel: originalImage.captionModel,
      captionTimestamp: originalImage.captionTimestamp,
      lastModified: DateTime.now(),
      tags: originalImage.tags,
    );
  }

  /// Compares two strings naturally, handling numerical parts correctly.
  ///
  /// This allows for sorting strings like 'file10.txt' after 'file2.txt'.
  @override
  int compareNatural(String a, String b) {
    final RegExp regex = RegExp(r'(\d+|\D+)');
    final List<String> aParts = regex
        .allMatches(a)
        .map((RegExpMatch m) => m.group(0)!)
        .toList();
    final List<String> bParts = regex
        .allMatches(b)
        .map((RegExpMatch m) => m.group(0)!)
        .toList();
    for (int i = 0; i < aParts.length && i < bParts.length; i++) {
      final int? aNum = int.tryParse(aParts[i]);
      final int? bNum = int.tryParse(bParts[i]);
      if (aNum != null && bNum != null) {
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else {
        final int cmp = aParts[i].compareTo(bParts[i]);
        if (cmp != 0) return cmp;
      }
    }
    return aParts.length.compareTo(bParts.length);
  }

  @override
  Future<List<AppImage>> getImagesSize(List<AppImage> images) =>
      ImageUtils.getImagesSize(images);

  @override
  Future<AppImage> getSingleImageSize(AppImage image) =>
      ImageUtils.getSingleImageSize(image);
}

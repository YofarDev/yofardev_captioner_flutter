import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/cache_service.dart';
import '../../../captioning/data/models/caption_data.dart';
import '../../../captioning/data/models/caption_database.dart';
import '../../../captioning/data/models/caption_entry.dart';
import '../../../structured_captioning/presentation/widgets/ideogram_caption_summary_card.dart';
import '../models/app_image.dart';

/// A utility class for file-related operations in the application.
class AppFileUtils {
  Future<List<AppImage>> onFolderPicked(String folderPath) async {
    final Directory dir = await _managePersistentPermission(folderPath);
    final CaptionDatabase db = await readDb(folderPath);
    bool dbWasModified = false;

    final List<FileSystemEntity> files = dir.listSync();
    final List<AppImage> images = <AppImage>[];
    final List<String> foundFilenames = <String>[];

    for (final FileSystemEntity file in files) {
      if (file is File) {
        final String extension = p.extension(file.path).toLowerCase();
        if (extension == '.jpg' ||
            extension == '.png' ||
            extension == '.jpeg' ||
            extension == '.webp') {
          final String filename = p.basename(file.path);
          foundFilenames.add(filename);

          final CaptionData captionData = db.images.firstWhere(
            (CaptionData d) => d.filename == filename,
            orElse: () {
              dbWasModified = true;
              return CaptionData(
                id: const Uuid().v4(),
                filename: filename,
                captions: <String, CaptionEntry>{},
              );
            },
          );

          final CaptionData hydratedCaptionData =
              await _hydrateCaptionDataFromLegacyTxt(
                captionData: captionData,
                folderPath: folderPath,
              );

          if (!identical(hydratedCaptionData, captionData)) {
            dbWasModified = true;
          }

          if (!db.images.contains(captionData)) {
            db.images.add(hydratedCaptionData);
          } else if (!identical(hydratedCaptionData, captionData)) {
            final int existingIndex = db.images.indexOf(captionData);
            db.images[existingIndex] = hydratedCaptionData;
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

    bool removedItems = false;
    db.images.removeWhere((CaptionData d) {
      final bool shouldRemove = !foundFilenames.contains(d.filename);
      if (shouldRemove) {
        removedItems = true;
      }
      return shouldRemove;
    });

    if (dbWasModified || removedItems) {
      await writeDb(folderPath, db);
    }

    images.sort(
      (AppImage a, AppImage b) => compareNatural(a.image.path, b.image.path),
    );
    return images;
  }

  Future<String?> _readLegacyCaptionText({
    required String folderPath,
    required String filename,
  }) async {
    final File txtFile = File(
      p.join(folderPath, p.setExtension(filename, '.txt')),
    );

    if (!await txtFile.exists()) {
      return null;
    }

    return txtFile.readAsString();
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

  Future<CaptionDatabase> readDb(String folderPath) async {
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
          return migrated;
        }

        final int version = (json['version'] as num?)?.toInt() ?? 1;
        if (version < 3) {
          final CaptionDatabase migrated = _migrateV2ToV3(json);
          await writeDb(folderPath, migrated);
          return migrated;
        }
        if (version < 4) {
          final CaptionDatabase migrated = _migrateV3ToV4(json);
          await writeDb(folderPath, migrated);
          return migrated;
        }
        return CaptionDatabase.fromJson(json);
      } catch (e) {
        return CaptionDatabase(
          categories: <String>['default'],
          activeCategory: 'default',
          images: <CaptionData>[],
        );
      }
    }

    // New folder - create with default structure
    return CaptionDatabase(
      categories: <String>['default'],
      activeCategory: 'default',
      images: <CaptionData>[],
    );
  }

  Future<void> writeDb(String folderPath, CaptionDatabase db) async {
    final File dbFile = _getDbPath(folderPath);
    final String content = jsonEncode(db.toJson());
    await dbFile.writeAsString(content);
  }

  Future<void> updateDbForRename(
    Map<String, String> oldNameToNewName,
    String folderPath,
  ) async {
    final CaptionDatabase db = await readDb(folderPath);

    for (final MapEntry<String, String> entry in oldNameToNewName.entries) {
      final String oldName = entry.key;
      final String newName = entry.value;
      try {
        final CaptionData data = db.images.firstWhere(
          (CaptionData d) => d.filename == oldName,
        );
        data.filename = newName;
      } catch (e) {
        // ignore
      }
    }

    await writeDb(folderPath, db);
  }

  Future<void> exportAsArchive(
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

      final String? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Please select an output file',
        fileName: fileName,
        initialDirectory: downloadsPath,
      );
      if (outputFile == null) {
        return;
      }

      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(outputFile);

      // Add images and their captions
      for (final AppImage image in images) {
        await encoder.addFile(image.image);

        final CaptionEntry? captionEntry = image.captions[category];
        if (captionEntry != null && captionEntry.text.isNotEmpty) {
          final bool isJson = IdeogramCaptionSummaryCard.isIdeogramJson(
            captionEntry.text,
          );
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
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to export archive: $e');
    }
  }

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

  Future<void> removeCaptionFiles(String folderPath, List<AppImage> images) async {
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

  Future<void> removeImage(File imageFile) async {
    await imageFile.delete();
    final String txtPath = p.setExtension(imageFile.path, '.txt');
    final File txtFile = File(txtPath);
    if (await txtFile.exists()) {
      await txtFile.delete();
    }
  }

  Future<void> saveCaptionToFile(AppImage image) async {
    // Captions are now saved in db.json, no need to write .txt files
    // final String txtPath = p.setExtension(image.image.path, '.txt');
    // await File(txtPath).writeAsString(image.caption);
  }

  Future<Directory> _managePersistentPermission(String folderPath) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Directory(folderPath);
    }
    if (!Platform.isMacOS) return Directory(folderPath);
    String? bookmark = await CacheService.loadMacosBookmark(
      folderPath: folderPath,
    );
    final SecureBookmarks secureBookmarks = SecureBookmarks();
    if (bookmark == null) {
      bookmark = await secureBookmarks.bookmark(Directory(folderPath));
      await CacheService.saveMacosBookmark(
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
        await CacheService.clearMacosBookmark(folderPath: folderPath);
        await CacheService.clearFolderPath();
        rethrow;
      }
    }
  }

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
}

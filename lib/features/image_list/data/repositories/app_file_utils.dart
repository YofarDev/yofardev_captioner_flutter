import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/app_image.dart';
import '../../../captioning/data/models/caption_data.dart';
import '../../../captioning/data/models/caption_database.dart';
import '../../../../core/services/cache_service.dart';

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
              return CaptionData(id: const Uuid().v4(), filename: filename);
            },
          );
          if (!db.images.contains(captionData)) {
            db.images.add(captionData);
          }
          // Always read caption from .txt file
          final String txtPath = p.setExtension(file.path, '.txt');
          String caption = '';
          if (await File(txtPath).exists()) {
            caption = await File(txtPath).readAsString();
          }

          images.add(
            AppImage(
              id: captionData.id,
              image: file,
              caption: caption,
              size: file.lengthSync(),
              captionModel: captionData.captionModel,
              captionTimestamp: captionData.captionTimestamp,
              lastModified: captionData.lastModified,
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

  File _getDbPath(String folderPath) {
    return File(p.join(folderPath, 'db.json'));
  }

  Future<CaptionDatabase> readDb(String folderPath) async {
    final File dbFile = _getDbPath(folderPath);
    if (await dbFile.exists()) {
      try {
        final String content = await dbFile.readAsString();
        return CaptionDatabase.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
      } catch (e) {
        // If file is corrupt or not valid JSON, return an empty DB
        return CaptionDatabase(images: <CaptionData>[]);
      }
    }
    return CaptionDatabase(images: <CaptionData>[]);
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

  Future<void> exportAsArchive(String folderPath, List<AppImage> images) async {
    final String? downloadsPath = await getDownloadsDirectory().then(
      (Directory? dir) => dir?.path,
    );
    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file',
      fileName: '${p.basename(folderPath)}.zip',
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
      if (image.caption.isNotEmpty) {
        final List<int> captionBytes = utf8.encode(image.caption);
        final ArchiveFile archiveFile = ArchiveFile(
          p.setExtension(p.basename(image.image.path), '.txt'),
          captionBytes.length,
          captionBytes,
        );
        encoder.addArchiveFile(archiveFile);
      }
    }

    // Add the captions.json file
    final File dbFile = _getDbPath(folderPath);
    if (await dbFile.exists()) {
      await encoder.addFile(dbFile);
    }

    encoder.close();
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
    final String txtPath = p.setExtension(image.image.path, '.txt');
    await File(txtPath).writeAsString(image.caption);
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
      final FileSystemEntity resolvedEntity = await secureBookmarks
          .resolveBookmark(bookmark);
      // Start accessing the security scoped resource
      await secureBookmarks.startAccessingSecurityScopedResource(
        resolvedEntity,
      );
      // Return a Directory object using the resolved path
      return Directory(resolvedEntity.path);
    }
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

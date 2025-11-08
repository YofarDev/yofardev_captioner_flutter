import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_image.dart';
import '../services/cache_service.dart';

/// A utility class for file-related operations in the application.
///
/// This includes renaming files, handling folder selections, exporting archives, and removing images.
class AppFileUtils {
  /// Renames image files in the specified [folderPath] to sequential numbers.
  ///
  /// It also renames corresponding caption files (.txt) if they exist.
  /// The renaming process involves temporary names to avoid conflicts.
  Future<void> renameFilesToNumbers(String folderPath) async {
    final List<String> imageExtensions = <String>[
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.JPG',
      '.JPEG',
      '.PNG',
      '.WEBP',
    ];

    final Directory directory = Directory(folderPath);
    final List<File> allFiles = directory.listSync().whereType<File>().toList();

    final List<File> imageFiles = allFiles.where((File file) {
      final String ext = p.extension(file.path);
      return imageExtensions.contains(ext);
    }).toList();

    final List<File> sortedImageFiles = _sortFiles(imageFiles);

    final int padding = sortedImageFiles.length.toString().length;

    final List<Map<String, dynamic>> renamingPlan = <Map<String, dynamic>>[];
    for (int i = 0; i < sortedImageFiles.length; i++) {
      final File originalFile = sortedImageFiles[i];
      final String suffix = p.extension(originalFile.path);
      final String newNumberStr = (i + 1).toString().padLeft(padding, '0');

      renamingPlan.add(<String, dynamic>{
        'originalPath': originalFile.path,
        'newNumber': newNumberStr,
        'suffix': suffix,
      });
    }

    final Map<String, Map<String, String>> tempRenames =
        <String, Map<String, String>>{};

    for (final Map<String, dynamic> plan in renamingPlan) {
      final String originalPath = plan['originalPath'] as String;
      final String newNumberStr = plan['newNumber'] as String;
      final String suffix = plan['suffix'] as String;

      final String tempFilename = 'temp_$newNumberStr$suffix';
      final String tempFullPath = p.join(folderPath, tempFilename);

      await File(originalPath).rename(tempFullPath);

      tempRenames[tempFullPath] = <String, String>{
        'original': p.basename(originalPath),
        'newNumber': newNumberStr,
        'suffix': suffix,
      };

      final String originalTextPath = '${p.withoutExtension(originalPath)}.txt';
      if (await File(originalTextPath).exists()) {
        final String tempTextFilename = 'temp_$newNumberStr.txt';
        final String tempTextFullPath = p.join(folderPath, tempTextFilename);
        await File(originalTextPath).rename(tempTextFullPath);
      }
    }

    for (final MapEntry<String, Map<String, String>> entry
        in tempRenames.entries) {
      final String tempFullPath = entry.key;
      final String newNumberStr = entry.value['newNumber']!;
      final String suffix = entry.value['suffix']!;

      final String finalFilename = '$newNumberStr$suffix';
      final String finalFullPath = p.join(folderPath, finalFilename);

      await File(tempFullPath).rename(finalFullPath);

      final String tempTextPath = '${p.withoutExtension(tempFullPath)}.txt';
      if (await File(tempTextPath).exists()) {
        final String finalTextFilename = '$newNumberStr.txt';
        final String finalTextFullPath = p.join(folderPath, finalTextFilename);
        await File(tempTextPath).rename(finalTextFullPath);
      }
    }
  }

  /// Sorts a list of [files] naturally by their base names.
  List<File> _sortFiles(List<File> files) {
    files.sort((File a, File b) {
      return compareNatural(p.basename(a.path), p.basename(b.path));
    });
    return files;
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

  /// Processes a selected [folderPath] to extract image files and their captions.
  ///
  /// Returns a sorted list of [AppImage] objects found in the folder.
  Future<List<AppImage>> onFolderPicked(String folderPath) async {
    final Directory dir = await _managePersistentPermission(folderPath);
    final List<FileSystemEntity> files = dir.listSync();
    final List<AppImage> images = <AppImage>[];

    for (final FileSystemEntity file in files) {
      if (file is File) {
        final String extension = p.extension(file.path).toLowerCase();
        if (extension == '.jpg' ||
            extension == '.png' ||
            extension == '.jpeg' ||
            extension == '.webp') {
          final String captionPath = p.setExtension(file.path, '.txt');
          final String caption = File(captionPath).existsSync()
              ? File(captionPath).readAsStringSync()
              : '';
          images.add(
            AppImage(image: file, caption: caption, size: file.lengthSync()),
          );
        }
      }
    }
    images.sort(
      (AppImage a, AppImage b) => a.image.path.compareTo(b.image.path),
    );
    return images;
  }

  Future<Directory> _managePersistentPermission(String folderPath) async {
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

  /// Exports all [images] and their associated caption files from [folderPath] into a zip archive.
  ///
  /// The user is prompted to select an output file location for the archive.
  /// Defaults to the Downloads folder.
  Future<void> exportAsArchive(String folderPath, List<AppImage> images) async {
    // Get the Downloads directory path
    final String? downloadsPath = await getDownloadsDirectory().then(
      (Directory? dir) => dir?.path,
    );

    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file',
      fileName: 'archive.zip',
      initialDirectory: downloadsPath,
    );

    if (outputFile == null) {
      return;
    }

    final ZipFileEncoder encoder = ZipFileEncoder();
    encoder.create(outputFile);

    for (final AppImage image in images) {
      await encoder.addFile(image.image);
      final File captionFile = File(p.setExtension(image.image.path, '.txt'));
      if (await captionFile.exists()) {
        await encoder.addFile(captionFile);
      }
    }

    encoder.close();
  }

  /// Removes an [image] file and its corresponding caption file from the file system.
  void removeImage(AppImage image) {
    image.image.deleteSync();
    final File captionFile = File(p.setExtension(image.image.path, '.txt'));
    if (captionFile.existsSync()) {
      captionFile.deleteSync();
    }
  }
}

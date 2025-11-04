import 'dart:io';

import 'package:path/path.dart' as path;

class FilesUtils {
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

    // Get all image files in the folder
    final Directory directory = Directory(folderPath);
    final List<File> allFiles = directory.listSync().whereType<File>().toList();

    final List<File> imageFiles = allFiles.where((File file) {
      final String ext = path.extension(file.path);
      return imageExtensions.contains(ext);
    }).toList();

    // Sort files naturally (you'll need to implement your sort logic)
    final List<File> sortedImageFiles = _sortFiles(imageFiles);

    // Calculate padding length
    final int padding = sortedImageFiles.length.toString().length;

    // Prepare renaming plan
    final List<Map<String, dynamic>> renamingPlan = <Map<String, dynamic>>[];
    for (int i = 0; i < sortedImageFiles.length; i++) {
      final File originalFile = sortedImageFiles[i];
      final String suffix = path.extension(originalFile.path);
      final String newNumberStr = (i + 1).toString().padLeft(padding, '0');

      renamingPlan.add(<String, dynamic>{
        'originalPath': originalFile.path,
        'newNumber': newNumberStr,
        'suffix': suffix,
      });
    }

    // First pass: Rename to temporary names
    final Map<String, Map<String, String>> tempRenames =
        <String, Map<String, String>>{};

    for (final Map<String, dynamic> plan in renamingPlan) {
      final String originalPath = plan['originalPath'] as String;
      final String newNumberStr = plan['newNumber'] as String;
      final String suffix = plan['suffix'] as String;

      final String tempFilename = 'temp_$newNumberStr$suffix';
      final String tempFullPath = path.join(folderPath, tempFilename);

      // Rename image file
      await File(originalPath).rename(tempFullPath);

      tempRenames[tempFullPath] = <String, String>{
        'original': path.basename(originalPath),
        'newNumber': newNumberStr,
        'suffix': suffix,
      };

      // Rename corresponding text file if exists
      final String originalTextPath =
          '${path.withoutExtension(originalPath)}.txt';
      if (await File(originalTextPath).exists()) {
        final String tempTextFilename = 'temp_$newNumberStr.txt';
        final String tempTextFullPath = path.join(folderPath, tempTextFilename);
        await File(originalTextPath).rename(tempTextFullPath);
      }
    }

    // Second pass: Rename from temporary to final names
    for (final MapEntry<String, Map<String, String>> entry
        in tempRenames.entries) {
      final String tempFullPath = entry.key;
      final String newNumberStr = entry.value['newNumber']!;
      final String suffix = entry.value['suffix']!;

      final String finalFilename = '$newNumberStr$suffix';
      final String finalFullPath = path.join(folderPath, finalFilename);

      // Rename image file
      await File(tempFullPath).rename(finalFullPath);

      // Rename corresponding text file if exists
      final String tempTextPath = '${path.withoutExtension(tempFullPath)}.txt';
      if (await File(tempTextPath).exists()) {
        final String finalTextFilename = '$newNumberStr.txt';
        final String finalTextFullPath = path.join(
          folderPath,
          finalTextFilename,
        );
        await File(tempTextPath).rename(finalTextFullPath);
      }
    }
  }

  // Natural sort helper function
  List<File> _sortFiles(List<File> files) {
    // Simple natural sort implementation
    files.sort((File a, File b) {
      return compareNatural(path.basename(a.path), path.basename(b.path));
    });
    return files;
  }

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

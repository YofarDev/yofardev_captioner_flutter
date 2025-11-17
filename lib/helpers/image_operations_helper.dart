import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../logic/images_list/image_list_cubit.dart';
import '../models/app_image.dart';
import '../utils/app_file_utils.dart';

class ImageOperationsHelper {
  final AppFileUtils _fileUtils;

  ImageOperationsHelper({AppFileUtils? fileUtils})
      : _fileUtils = fileUtils ?? AppFileUtils();

  Future<void> renameAllFiles(String folderPath) async {
    List<AppImage> images = await _fileUtils.onFolderPicked(folderPath);
    images = _fileUtils.sortAppImages(images);
    final int totalFiles = images.length;
    final int padding = max(2, totalFiles.toString().length);
    // First pass: rename to temporary names to avoid conflicts
    final List<File> tempFiles = <File>[];
    for (int i = 0; i < images.length; i++) {
      final File file = images[i].image;
      final String tempName = 'temp_$i${p.extension(file.path)}';
      final File renamedFile = await file.rename(
        p.join(p.dirname(file.path), tempName),
      );
      tempFiles.add(renamedFile);
      final File captionFile = File(
        p.setExtension(images[i].image.path, '.txt'),
      );
      if (await captionFile.exists()) {
        final String tempCaptionName = 'temp_$i.txt';
        await captionFile.rename(
          p.join(p.dirname(captionFile.path), tempCaptionName),
        );
      }
    }
    // Second pass: rename from temporary to final names (starting from 1)
    for (int i = 0; i < tempFiles.length; i++) {
      final String paddedIndex = (i + 1).toString().padLeft(padding, '0');
      final File tempFile = tempFiles[i];
      final String newName = '$paddedIndex${p.extension(tempFile.path)}';
      await tempFile.rename(p.join(p.dirname(tempFile.path), newName));

      final String tempCaptionPath = p.setExtension(tempFile.path, '.txt');
      final File tempCaptionFile = File(tempCaptionPath);
      if (await tempCaptionFile.exists()) {
        await tempCaptionFile.rename(
          p.join(p.dirname(tempCaptionFile.path), '$paddedIndex.txt'),
        );
      }
    }
  }

  Future<void> exportAsArchive(String folderPath, List<AppImage> images) async {
    await _fileUtils.exportAsArchive(folderPath, images);
  }

  Stream<ImageListState> convertAllImages({
    required String format,
    required int quality,
    required ImageListState state,
  }) async* {
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    for (int i = 0; i < updatedImages.length; i++) {
      final AppImage image = updatedImages[i];
      final String newPath = p.setExtension(image.image.path, '.$format');
      final ProcessResult result = await Process.run('convert', <String>[
        image.image.path,
        '-quality',
        quality.toString(),
        newPath,
      ]);
      if (result.exitCode == 0) {
        await image.image.delete();
        updatedImages[i] = image.copyWith(image: File(newPath));
      } else {
        updatedImages[i] = image.copyWith(error: result.stderr as String);
      }
      yield state.copyWith(images: updatedImages);
    }
  }

  Future<ImageListState?> cropCurrentImage(
    BuildContext context,
    ImageListState state,
  ) async {
    final AppImage currentImage = state.images[state.currentIndex];
    final File? result = await Navigator.push(
      context,
      MaterialPageRoute<File>(
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(
            title: const Text('Crop Image'),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.done),
                onPressed: () => Navigator.pop(context, 'done'),
              ),
            ],
          ),
          body: Crop(
            image: currentImage.image.readAsBytesSync(),
            onCropped: (Uint8List croppedData) async {
              final Directory tempDir = await getTemporaryDirectory();
              final File tempFile = File(
                '${tempDir.path}/${const Uuid().v4()}.png',
              );
              await tempFile.writeAsBytes(croppedData);
              Navigator.pop(context, tempFile);
            },
          ),
        ),
      ),
    );

    if (result is File) {
      final String newPath = p.setExtension(
        currentImage.image.path,
        '.${result.path.split('.').last}',
      );
      await result.copy(newPath);
      final List<AppImage> updatedImages = List<AppImage>.from(state.images);
      updatedImages[state.currentIndex] = currentImage.copyWith(
        image: File(newPath),
      );
      return state.copyWith(images: updatedImages);
    }
    return null;
  }
}

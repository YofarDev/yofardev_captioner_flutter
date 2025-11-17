import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../logic/images_list/image_list_cubit.dart';
import '../models/app_image.dart';
import '../models/crop_image.dart';
import '../screens/main/crop_image_screen.dart';
import '../utils/app_file_utils.dart';
import '../utils/image_utils.dart';

class ImageOperationsHelper {
  final AppFileUtils _fileUtils;

  ImageOperationsHelper({AppFileUtils? fileUtils})
    : _fileUtils = fileUtils ?? AppFileUtils();

  Future<void> renameAllFiles(String folderPath) async {
    List<AppImage> images = await _fileUtils.onFolderPicked(folderPath);
    images = _fileUtils.sortAppImages(images);
    final int totalFiles = images.length;
    final int padding = max(2, totalFiles.toString().length);
    // Create a temporary directory
    final Directory tempDir = Directory(p.join(folderPath, 'temp_rename'));
    await tempDir.create();
    try {
      // Copy all files to temp directory with new names
      for (int i = 0; i < images.length; i++) {
        final String paddedIndex = (i + 1).toString().padLeft(padding, '0');
        final File file = images[i].image;
        final String extension = p.extension(file.path);

        // Copy image with new name
        final String newImageName = '$paddedIndex$extension';
        await file.copy(p.join(tempDir.path, newImageName));

        // Copy caption file if it exists
        final File captionFile = File(p.setExtension(file.path, '.txt'));
        if (await captionFile.exists()) {
          await captionFile.copy(p.join(tempDir.path, '$paddedIndex.txt'));
        }
      }
      // Delete all original files
      for (final AppImage image in images) {
        await image.image.delete();
        final File captionFile = File(p.setExtension(image.image.path, '.txt'));
        if (await captionFile.exists()) {
          await captionFile.delete();
        }
      }
      // Move files from temp directory back to original folder
      final List<FileSystemEntity> tempFiles = tempDir.listSync();
      for (final FileSystemEntity entity in tempFiles) {
        if (entity is File) {
          final String fileName = p.basename(entity.path);
          await entity.rename(p.join(folderPath, fileName));
        }
      }
      // Delete temp directory
      await tempDir.delete();
    } catch (e) {
      // If something goes wrong, try to clean up the temp directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
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
    final CropImage? result = await Navigator.push(
      context,
      MaterialPageRoute<CropImage>(
        builder: (BuildContext context) =>
            CropImageScreen(image: currentImage.image.readAsBytesSync()),
      ),
    );
    if (result is CropImage && result.bytes != null) {
      if (result.targetAspectRatio == currentImage.aspectRatioAsDouble) {
        return null;
      }
      final String newPath = p.setExtension(currentImage.image.path, '.png');
      // Write the bytes to the file
      final File newFile = File(newPath);
      final Uint8List resizedBytes = await _resizeImage(currentImage, result);
      await newFile.writeAsBytes(resizedBytes);
      final List<AppImage> updatedImages = List<AppImage>.from(state.images);
      updatedImages[state.currentIndex] = currentImage.copyWith(image: newFile);
      return state.copyWith(images: updatedImages);
    }
    return null;
  }

  Future<Uint8List> _resizeImage(
    AppImage originalImage,
    CropImage croppedImage,
  ) async {
    final img.Image? decodedCroppedImage = img.decodeImage(croppedImage.bytes!);
    if (decodedCroppedImage == null) {
      throw Exception('Failed to decode image');
    }
    final Map<String, int> newResolution =
        ImageUtils.getClosestSmallerResolution(
          width: decodedCroppedImage.width,
          height: decodedCroppedImage.height,
          aspectRatio: 16 / 9,
        );
    print(newResolution);
    final img.Image resizedImage = img.copyResize(
      decodedCroppedImage,
      width: newResolution['width'],
      height: newResolution['height'],
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodePng(resizedImage));
  }
}

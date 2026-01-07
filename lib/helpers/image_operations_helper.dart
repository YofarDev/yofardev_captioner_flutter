import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../features/image_list/data/models/app_image.dart';
import '../features/image_list/data/repositories/app_file_utils.dart';
import '../features/image_list/logic/image_list_cubit.dart';
import '../features/image_operations/data/models/crop_image.dart';
import '../features/image_operations/data/utils/image_utils.dart';
import '../features/image_operations/presentation/pages/crop_image_screen.dart';

class ImageOperationsHelper {
  final AppFileUtils _fileUtils;
  final ImageListCubit _imageListCubit;

  ImageOperationsHelper({
    AppFileUtils? fileUtils,
    required ImageListCubit imageListCubit,
  }) : _fileUtils = fileUtils ?? AppFileUtils(),
       _imageListCubit = imageListCubit;

  Future<void> renameAllFiles(String folderPath) async {
    final List<AppImage> images = List<AppImage>.from(
      _imageListCubit.state.images,
    );
    final List<File> currentImageFiles = images
        .map((AppImage e) => e.image)
        .toList();
    final List<File> sortedImageFiles = _sortFiles(currentImageFiles);

    final int totalFiles = sortedImageFiles.length;
    final int padding = math.max(2, totalFiles.toString().length);

    final Map<String, String> oldNameToNewName = <String, String>{};

    // Perform renames and update AppImage objects
    for (int i = 0; i < sortedImageFiles.length; i++) {
      final File originalFile = sortedImageFiles[i];
      final String paddedIndex = (i + 1).toString().padLeft(padding, '0');
      final String extension = p.extension(originalFile.path);

      final String newImageName = '$paddedIndex$extension';
      final String newPath = p.join(folderPath, newImageName);

      oldNameToNewName[p.basename(originalFile.path)] = newImageName;

      await originalFile.rename(newPath);

      // Also rename caption file if it exists
      final String oldCaptionPath = p.setExtension(originalFile.path, '.txt');
      if (await File(oldCaptionPath).exists()) {
        final String newCaptionPath = p.setExtension(newPath, '.txt');
        await File(oldCaptionPath).rename(newCaptionPath);
      }
    }

    await _fileUtils.updateDbForRename(oldNameToNewName, folderPath);

    // Refresh the image list and update the database
    await _imageListCubit.onFolderPicked(folderPath);
  }

  /// Sorts a list of [files] naturally by their base names.
  List<File> _sortFiles(List<File> files) {
    files.sort((File a, File b) {
      return _fileUtils.compareNatural(p.basename(a.path), p.basename(b.path));
    });
    return files;
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
      if (result.targetAspectRatio ==
          Size(currentImage.width.toDouble(), currentImage.height.toDouble())) {
        return null;
      }
      final File originalFile = currentImage.image;
      final String originalExt = p.extension(originalFile.path).toLowerCase();
      final bool originalWasPng = originalExt == '.png';
      // newPath: if original already png keep same path, otherwise change extension to .png
      final String newPath = originalWasPng
          ? originalFile.path
          : p.setExtension(originalFile.path, '.png');

      final File newFile = File(newPath);
      final Uint8List resizedBytes = await _resizeImage(currentImage, result);
      try {
        // Write the new PNG bytes (overwrites if same path)
        await newFile.writeAsBytes(resizedBytes);
        // Update state to point to the new file
        final List<AppImage> updatedImages = List<AppImage>.from(state.images);
        updatedImages[state.currentIndex] = currentImage.copyWith(
          id: const Uuid().v4(),
          image: newFile,
        );
        final ImageListState newState = state.copyWith(images: updatedImages);
        // If original wasn't a PNG and the paths differ, attempt to delete the original file
        if (!originalWasPng && originalFile.path != newFile.path) {
          try {
            if (await originalFile.exists()) {
              await originalFile.delete();
            }
          } catch (deleteErr) {
            debugPrint('Failed to delete original file: $deleteErr');
          }
        }
        return newState;
      } catch (writeErr) {
        rethrow;
      }
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
    final Size? newResolution = ImageUtils.getExactResolutionWithinBounds(
      original: Size(
        originalImage.width.toDouble(),
        originalImage.height.toDouble(),
      ),
      aspect: croppedImage.targetAspectRatio,
    );
    if (newResolution == null) {
      throw Exception('Failed to calculate new resolution');
    }
    final img.Image resizedImage = img.copyResize(
      decodedCroppedImage,
      width: newResolution.width.toInt(),
      height: newResolution.height.toInt(),
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodePng(resizedImage));
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/errors/exception_mapper.dart';
import '../core/errors/failure.dart';
import '../core/models/app_image.dart';
import '../core/utils/image_utils.dart';
import '../features/image_list/data/repositories/app_file_utils.dart';
import '../features/image_list/image_list.dart';
import '../features/image_operations/image_operations.dart';

class ImageOperationsHelper {
  static final Logger _logger = Logger('ImageOperationsHelper');

  final AppFileUtils _fileUtils;
  final CaptionSessionService _session;

  ImageOperationsHelper({
    AppFileUtils? fileUtils,
    required CaptionSessionService session,
  }) : _fileUtils = fileUtils ?? AppFileUtils(),
       _session = session;

  Future<Either<Failure, void>> renameAllFiles(String folderPath) async {
    try {
      return await _renameAllFiles(folderPath);
    } catch (e, st) {
      return Left<Failure, void>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'ImageOperationsHelper.renameAllFiles',
        ),
      );
    }
  }

  Future<Either<Failure, void>> _renameAllFiles(String folderPath) async {
    final List<AppImage> images = List<AppImage>.from(_session.state.images);
    final List<File> currentImageFiles = images
        .map((AppImage e) => e.image)
        .toList();
    final List<File> sortedImageFiles = _sortFiles(currentImageFiles);

    final int totalFiles = sortedImageFiles.length;
    final int padding = math.max(2, totalFiles.toString().length);

    final Map<String, String> oldNameToNewName = <String, String>{};

    // Pass 1: Rename all files to temporary unique names to prevent collisions
    // when sequential targets overlap with existing file names
    final List<String> tempImagePaths = <String>[];
    final List<List<String>> tempCaptionPaths = <List<String>>[];

    const List<String> captionExts = <String>['.txt', '.json'];

    for (int i = 0; i < sortedImageFiles.length; i++) {
      final File originalFile = sortedImageFiles[i];
      final String extension = p.extension(originalFile.path);
      final String paddedIndex = (i + 1).toString().padLeft(padding, '0');
      final String finalName = '$paddedIndex$extension';

      oldNameToNewName[p.basename(originalFile.path)] = finalName;

      final String tempImagePath = p.join(
        folderPath,
        '.tmp_rename_${const Uuid().v4()}$extension',
      );
      await originalFile.rename(tempImagePath);
      tempImagePaths.add(tempImagePath);

      final List<String> captionTemps = <String>[];
      for (final String ext in captionExts) {
        final String oldCaptionPath = p.setExtension(originalFile.path, ext);
        if (await File(oldCaptionPath).exists()) {
          final String tempCaptionPath = p.join(
            folderPath,
            '.tmp_rename_${const Uuid().v4()}$ext',
          );
          await File(oldCaptionPath).rename(tempCaptionPath);
          captionTemps.add(tempCaptionPath);
        }
      }
      tempCaptionPaths.add(captionTemps);
    }

    // Pass 2: Rename from temporary to final sequential names
    for (int i = 0; i < tempImagePaths.length; i++) {
      final String paddedIndex = (i + 1).toString().padLeft(padding, '0');
      final String extension = p.extension(tempImagePaths[i]);
      final String finalImageName = '$paddedIndex$extension';
      final String finalImagePath = p.join(folderPath, finalImageName);

      await File(tempImagePaths[i]).rename(finalImagePath);

      for (final String tempCaptionPath in tempCaptionPaths[i]) {
        final String ext = p.extension(tempCaptionPath);
        final String finalCaptionName = '$paddedIndex$ext';
        final String finalCaptionPath = p.join(folderPath, finalCaptionName);
        await File(tempCaptionPath).rename(finalCaptionPath);
      }
    }

    await _fileUtils.updateDbForRename(oldNameToNewName, folderPath);

    // Refresh the image list and update the database
    await _session.onFolderPicked(folderPath);
    return const Right<Failure, void>(null);
  }

  /// Sorts a list of [files] naturally by their base names.
  List<File> _sortFiles(List<File> files) {
    files.sort((File a, File b) {
      return _fileUtils.compareNatural(p.basename(a.path), p.basename(b.path));
    });
    return files;
  }

  Future<Either<Failure, void>> exportAsArchive(
    String folderPath,
    List<AppImage> images,
    String category,
  ) => _fileUtils.exportAsArchive(folderPath, images, category);

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
    final AppImage? currentImage = _session.current.currentDisplayedImage;
    if (currentImage == null) {
      return null;
    }

    // Convert to PNG first for lossless quality during crop
    final Uint8List originalBytes = currentImage.image.readAsBytesSync();
    final String originalExt = p
        .extension(currentImage.image.path)
        .toLowerCase();
    Uint8List pngBytes;

    if (originalExt == '.png') {
      pngBytes = originalBytes;
    } else {
      // Decode using Flutter's codec at full resolution, then re-encode as PNG
      final ui.Codec codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: currentImage.width,
        targetHeight: currentImage.height,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Convert to byte data
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        _logger.warning('Failed to convert image to PNG bytes');
        codec.dispose();
        image.dispose();
        return null;
      }
      pngBytes = byteData.buffer.asUint8List();

      codec.dispose();
      image.dispose();
      _logger.warning(
        'Converted to PNG using Flutter codec: ${pngBytes.length} bytes',
      );
    }

    _logger.warning('Passing to crop screen: ${pngBytes.length} bytes');

    final CropImage? result = await Navigator.push(
      context,
      MaterialPageRoute<CropImage>(
        builder: (BuildContext context) => CropImageScreen(image: pngBytes),
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
        final int index = updatedImages.indexWhere(
          (AppImage i) => i.id == currentImage.id,
        );
        if (index == -1) {
          return null;
        }
        final String newId = const Uuid().v4();
        updatedImages[index] = currentImage.copyWith(id: newId, image: newFile);
        final ImageListState newState = state.copyWith(
          images: updatedImages,
          currentImageId: newId,
        );
        // If original wasn't a PNG and the paths differ, attempt to delete the original file
        if (!originalWasPng && originalFile.path != newFile.path) {
          try {
            if (await originalFile.exists()) {
              await originalFile.delete();
            }
          } catch (deleteErr) {
            _logger.warning('Failed to delete original file: $deleteErr');
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

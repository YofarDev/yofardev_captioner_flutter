import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;

import '../../../models/app_image.dart';
import '../../../utils/app_file_utils.dart';
import '../../../utils/image_utils.dart';
import '../images_cubit.dart';

class ImageOperationsHelper {
  final AppFileUtils _fileUtils = AppFileUtils();

  Future<void> renameAllFiles(String folderPath) async {
    await _fileUtils.renameFilesToNumbers(folderPath);
  }

  Future<void> exportAsArchive(String folderPath, List<AppImage> images) async {
    await _fileUtils.exportAsArchive(folderPath, images);
  }

  ImagesState removeImage(int index, ImagesState state) {
    final AppImage image = state.images[index];
    _fileUtils.removeImage(image);

    final List<AppImage> updatedImages = List<AppImage>.from(state.images)
      ..removeAt(index);

    int newCurrentIndex = state.currentIndex;
    if (index == newCurrentIndex) {
      if (updatedImages.isEmpty) {
        newCurrentIndex = 0;
      } else if (index >= updatedImages.length) {
        newCurrentIndex = updatedImages.length - 1;
      }
    }

    return state.copyWith(images: updatedImages, currentIndex: newCurrentIndex);
  }

  Stream<ImagesState> convertAllImages({
    required String format,
    required int quality,
    required ImagesState state,
  }) async* {
    if (state.folderPath == null) {
      return;
    }
    yield state.copyWith(isConverting: true, conversionLog: '');
    try {
      await for (final Map<String, String> update
          in ImageUtils.convertAllImages(
            folderPath: state.folderPath!,
            format: format,
            quality: quality,
          )) {
        yield* _updateConvertedImage(update, format, state);
      }
    } catch (e) {
      debugPrint(e.toString());
      yield state.copyWith(conversionLog: e.toString());
    } finally {
      yield state.copyWith(isConverting: false);
    }
  }

  Stream<ImagesState> _updateConvertedImage(
    Map<String, String> update,
    String format,
    ImagesState state,
  ) async* {
    final String filename = update['filename']!;
    final int index = state.images.indexWhere(
      (AppImage image) =>
          p.basename(image.image.path).split('.')[0] == filename,
    );
    if (index != -1) {
      final List<AppImage> updatedImages = List<AppImage>.from(state.images);
      final String newFullPath = p.join(state.folderPath!, "$filename.$format");

      updatedImages[index] = updatedImages[index].copyWith(
        image: File(newFullPath),
      );
      yield state.copyWith(images: updatedImages);
    }
  }

  Future<ImagesState?> cropCurrentImage(ImagesState state) async {
    final AppImage currentImage = state.images[state.currentIndex];
    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: currentImage.image.path,
      uiSettings: <PlatformUiSettings>[
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: <CropAspectRatioPreset>[
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    if (croppedFile != null) {
      return _processCroppedImage(croppedFile, state);
    }
    return null;
  }

  Future<ImagesState> _processCroppedImage(
    CroppedFile croppedFile,
    ImagesState state,
  ) async {
    final AppImage currentImage = state.images[state.currentIndex];
    final Uint8List bytes = await croppedFile.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);

    if (image != null) {
      final int newWidth = (image.width / 8).round() * 8;
      final int newHeight = (image.height / 8).round() * 8;

      final img.Image resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
      );

      final List<int> resizedBytes;
      final String extension = p
          .extension(currentImage.image.path)
          .toLowerCase();
      if (extension == '.jpg' || extension == '.jpeg') {
        resizedBytes = img.encodeJpg(resizedImage);
      } else {
        resizedBytes = img.encodePng(resizedImage);
      }

      await currentImage.image.writeAsBytes(resizedBytes);

      // Reload the image to update UI
      final List<AppImage> updatedImages = List<AppImage>.from(state.images);
      final AppImage updatedImage = await ImageUtils.getImagesSize(<AppImage>[
        AppImage(image: currentImage.image, caption: currentImage.caption),
      ]).then((List<AppImage> value) => value.first);
      updatedImages[state.currentIndex] = updatedImage;
      return state.copyWith(images: updatedImages);
    }
    return state;
  }
}

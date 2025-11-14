import 'dart:io';
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
  final AppFileUtils _fileUtils = AppFileUtils();

  Future<void> renameAllFiles(String folderPath) async {
    final List<AppImage> images = await _fileUtils.onFolderPicked(folderPath);
    for (final AppImage image in images) {
      final File file = image.image;
      final String newName = '${const Uuid().v4()}${p.extension(file.path)}';
      await file.rename(p.join(p.dirname(file.path), newName));
      final File captionFile = File(p.setExtension(file.path, '.txt'));
      if (await captionFile.exists()) {
        await captionFile.rename(p.join(p.dirname(file.path), newName));
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

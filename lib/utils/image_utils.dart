import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/app_image.dart';

/// A utility class for image-related operations.
///
/// This includes getting image dimensions, opening images with default applications,
/// and retrieving image file sizes.
class ImageUtils {
  /// Asynchronously retrieves the dimensions (width and height) of an image.
  ///
  /// [imagePath]: The file path of the image.
  /// Returns a [Future] that completes with a [Size] object representing the image's dimensions.
  static Future<Size> getImageDimensions(String imagePath) async {
    final File imageFile = File(imagePath);
    final Uint8List bytes = await imageFile.readAsBytes();

    final ui.Codec codec = await ui.instantiateImageCodec(bytes);

    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final int width = image.width;
    final int height = image.height;

    image.dispose();
    codec.dispose();

    return Size(width.toDouble(), height.toDouble());
  }

  /// Opens the image at the given [imagePath] using the operating system's default application.
  ///
  /// Supports macOS, Windows, and Linux.
  static void openImageWithDefaultApp(String imagePath) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', <String>[imagePath]);
      } else if (Platform.isWindows) {
        await Process.run('start', <String>[imagePath], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', <String>[imagePath]);
      }
    } catch (e) {
      debugPrint('Error opening image: $e');
    }
  }

  /// Asynchronously retrieves the dimensions and file size for a list of [AppImage]s.
  ///
  /// [images]: The list of [AppImage]s to update.
  /// Returns a [Future] that completes with a new list of [AppImage]s,
  /// each updated with its width, height, and file size.
  static Future<List<AppImage>> getImagesSize(List<AppImage> images) async {
    final List<AppImage> updated = <AppImage>[];
    for (final AppImage image in images) {
      final Size size = await getImageDimensions(image.image.path);
      updated.add(
        image.copyWith(
          width: size.width.toInt(),
          height: size.height.toInt(),
          size: image.image.lengthSync(),
        ),
      );
    }
    return updated;
  }
}

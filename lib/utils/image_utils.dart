import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_image.dart';
import 'bash_scripts_runner.dart';

/// A utility class for image-related operations.
///
/// This includes getting image dimensions, opening images with default applications,
/// and retrieving image file sizes.
class ImageUtils {
  static const int maxFileSize = 5 * 1024 * 1024;

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

  static Future<AppImage> getSingleImageSize(AppImage image) async {
    final Size size = await getImageDimensions(image.image.path);
    return image.copyWith(
      width: size.width.toInt(),
      height: size.height.toInt(),
      size: image.image.lengthSync(),
    );
  }

  static Stream<Map<String, String>> convertAllImages({
    required String folderPath,
    required String format,
    required int quality,
  }) async* {
    const String scriptAssetPath = 'assets/scripts/convert_images.sh';
    final String scriptContent = await rootBundle.loadString(scriptAssetPath);
    final Process process = await BashScriptsRunnner.run(
      scriptContent,
      <String>[folderPath, format, quality.toString()],
    );
    final Stream<String> stdoutStream = process.stdout.transform(utf8.decoder);
    await for (final String line in stdoutStream) {
      if (line.contains('→')) {
        final List<String> parts = line.split('→');
        final String filename = parts[0]
            .split('Converting ')[1]
            .trim()
            .split('.')[0];
        yield <String, String>{'filename': filename};
      }
    }
  }

  static String getSimplifiedAspectRatio(int width, int height) {
    if (width <= 0 || height <= 0) {
      return '...';
    }
    final int gcd = _gcd(width, height);
    return '${width ~/ gcd}:${height ~/ gcd}';
  }

  static int _gcd(int a, int b) {
    if (b == 0) {
      return a;
    }
    return _gcd(b, a % b);
  }

  static Size? getExactResolutionWithinBounds({
    required Size original,
    required Size aspect,
  }) {
    // Convert to integers
    final int maxW = original.width.floor();
    final int maxH = original.height.floor();
    final int aw = aspect.width.floor();
    final int ah = aspect.height.floor();
    if (aw <= 0 || ah <= 0) return null;
    // Reduce aspect ratio
    final int g = _gcd(aw, ah);
    final int p = aw ~/ g; // reduced width unit
    final int q = ah ~/ g; // reduced height unit
    // Largest integer scale k such that p*k <= maxW AND q*k <= maxH
    final int k = min(maxW ~/ p, maxH ~/ q);
    if (k < 1) return null;
    final int finalW = p * k;
    final int finalH = q * k;
    return Size(finalW.toDouble(), finalH.toDouble());
  }

  static Future<File> resizeImageIfNecessary(File imageFile) async {
    final int fileSize = await imageFile.length();
    if (fileSize <= maxFileSize) {
      return imageFile;
    }

    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = p.join(
      tempDir.path,
      '${p.basename(imageFile.path)}_compressed.jpg',
    );

    int quality = 95;
    File compressedImageFile = imageFile;

    while (await compressedImageFile.length() > maxFileSize && quality > 10) {
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        tempPath,
        quality: quality,
      );

      if (result != null) {
        compressedImageFile = File(result.path);
        quality -= 5;
      } else {
        // if compression fails, return original file
        return imageFile;
      }
    }

    return compressedImageFile;
  }
}

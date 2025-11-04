import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ImageUtils {
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
}

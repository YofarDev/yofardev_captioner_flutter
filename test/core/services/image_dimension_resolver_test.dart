import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yofardev_captioner/core/services/image_dimension_resolver.dart';

/// Builds a minimal EXIF APP1 segment carrying a single orientation tag.
Uint8List exifApp1(int orientation) {
  // TIFF: II marker, 42, IFD offset 8, 1 entry, tag 0x0112 (orientation),
  // type 3 (SHORT), count 1, value, next-IFD 0.
  final ByteData tiff = ByteData(26);
  int o = 2; // after the II byte-order marker
  void u16(int v) {
    tiff.setUint16(o, v, Endian.little);
    o += 2;
  }

  void u32(int v) {
    tiff.setUint32(o, v, Endian.little);
    o += 4;
  }

  // 'II'
  tiff.setUint8(0, 0x49);
  tiff.setUint8(1, 0x49);
  // TIFF magic 42 is a SHORT; the first-IFD offset (8) is a LONG.
  u16(42);
  u32(8);
  // IFD: 1 entry
  u16(1);
  u16(0x0112); // Orientation tag
  u16(3); // SHORT
  u32(1); // Count
  u16(orientation); // Value (first SHORT slot)
  u16(0); // Padding
  u32(0); // Next IFD: none

  final BytesBuilder builder = BytesBuilder();
  builder.add(<int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00]); // 'Exif\0\0'
  builder.add(tiff.buffer.asUint8List());
  final Uint8List payload = builder.toBytes();

  // APP1 segment: marker, big-endian length (payload + 2), payload.
  final BytesBuilder segment = BytesBuilder();
  segment.add(<int>[0xFF, 0xE1]);
  segment.add(<int>[(payload.length + 2) >> 8, (payload.length + 2) & 0xFF]);
  segment.add(payload);
  return segment.toBytes();
}

/// Injects [exif] after the JPEG SOI marker of [jpeg].
Uint8List withExif(Uint8List jpeg, Uint8List exif) {
  final BytesBuilder builder = BytesBuilder();
  builder.add(jpeg.sublist(0, 2)); // FFD8
  builder.add(exif);
  builder.add(jpeg.sublist(2));
  return builder.toBytes();
}

Uint8List encodeJpeg(int width, int height) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(1, 2, 3));
  // Asymmetric content so any axis swap is visible in decoded pixels.
  img.drawPixel(image, 0, 0, img.ColorRgb8(255, 0, 0));
  img.drawPixel(image, width - 1, height - 1, img.ColorRgb8(0, 0, 255));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  // Codex review finding 5: the header fast path reported the *stored*
  // JPEG frame and ignored EXIF orientation.
  group('ImageDimensionResolver EXIF handling', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('exif_resolver_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    File write(String name, Uint8List bytes) {
      final File f = File('${tempDir.path}/$name')..writeAsBytesSync(bytes);
      return f;
    }

    test(
      'orientation 6 JPEG reports the display frame (axes swapped)',
      () async {
        // Stored 80×40, EXIF says "rotate 90 CW" → display 40×80.
        final File file = write(
          'rot90.jpg',
          withExif(encodeJpeg(80, 40), exifApp1(6)),
        );
        final ImageDimensions? dims = await const ImageDimensionResolver()
            .resolve(file);
        expect(dims, isNotNull);
        expect(dims!.width, 40, reason: 'display width after rotate-90');
        expect(dims.height, 80, reason: 'display height after rotate-90');
      },
    );

    test('orientation 8 JPEG also swaps axes', () async {
      final File file = write(
        'rot270.jpg',
        withExif(encodeJpeg(80, 40), exifApp1(8)),
      );
      final ImageDimensions? dims = await const ImageDimensionResolver()
          .resolve(file);
      expect(dims!.width, 40);
      expect(dims.height, 80);
    });

    test('orientation 2 (mirror) keeps axes but decodes', () async {
      final File file = write(
        'mirror.jpg',
        withExif(encodeJpeg(80, 40), exifApp1(2)),
      );
      final ImageDimensions? dims = await const ImageDimensionResolver()
          .resolve(file);
      expect(dims!.width, 80);
      expect(dims.height, 40);
    });

    test('orientation-less JPEG still uses the fast path', () async {
      final File file = write('plain.jpg', encodeJpeg(80, 40));
      final ImageDimensions? dims = await const ImageDimensionResolver()
          .resolve(file);
      expect(dims!.width, 80);
      expect(dims.height, 40);
    });

    test('PNG headers remain orientation-free and fast', () async {
      final img.Image image = img.Image(width: 64, height: 32);
      img.fill(image, color: img.ColorRgb8(9, 9, 9));
      final File file = write(
        'plain.png',
        Uint8List.fromList(img.encodePng(image)),
      );
      final ImageDimensions? dims = await const ImageDimensionResolver()
          .resolve(file);
      expect(dims!.width, 64);
      expect(dims.height, 32);
    });
  });
}

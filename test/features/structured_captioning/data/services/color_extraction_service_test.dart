import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yofardev_captioner/features/structured_captioning/data/services/color_extraction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColorExtractionService', () {
    late ColorExtractionService service;

    setUp(() {
      service = ColorExtractionService();
    });

    /// Creates a temporary PNG with horizontal color bands.
    File createBandedImage(
      List<img.Color> bands, {
      int width = 200,
      int height = 200,
    }) {
      final img.Image image = img.Image(width: width, height: height);
      final int bandHeight = height ~/ bands.length;
      for (int b = 0; b < bands.length; b++) {
        for (
          int y = b * bandHeight;
          y < (b + 1) * bandHeight && y < height;
          y++
        ) {
          for (int x = 0; x < width; x++) {
            image.setPixel(x, y, bands[b]);
          }
        }
      }
      final Directory tmpDir = Directory.systemTemp.createTempSync(
        'color_test_',
      );
      final File file = File('${tmpDir.path}/test.png');
      file.writeAsBytesSync(img.encodePng(image));
      return file;
    }

    group('extractPalette', () {
      test('extracts single color from solid image', () async {
        final File file = createBandedImage(<img.Color>[
          img.ColorRgb8(255, 0, 0),
        ]);
        final List<String> palette = await service.extractPalette(
          file,
          colorCount: 3,
        );

        expect(palette, isNotEmpty);
        // All colors should be near red.
        for (final String hex in palette) {
          final int r = int.parse(hex.substring(1, 3), radix: 16);
          final int g = int.parse(hex.substring(3, 5), radix: 16);
          final int b = int.parse(hex.substring(5, 7), radix: 16);
          expect(r, greaterThan(200));
          expect(g, lessThan(50));
          expect(b, lessThan(50));
        }
      });

      test('extracts two dominant colors from bichrome image', () async {
        final File file = createBandedImage(<img.Color>[
          img.ColorRgb8(0, 0, 255), // blue
          img.ColorRgb8(255, 255, 0), // yellow
        ]);
        final List<String> palette = await service.extractPalette(
          file,
          colorCount: 2,
        );

        expect(palette, hasLength(2));

        // Check that we have one blue-ish and one yellow-ish.
        final List<bool> isBlue = palette.map((String hex) {
          final int r = int.parse(hex.substring(1, 3), radix: 16);
          final int b = int.parse(hex.substring(5, 7), radix: 16);
          return b > r + 100;
        }).toList();

        final List<bool> isYellow = palette.map((String hex) {
          final int r = int.parse(hex.substring(1, 3), radix: 16);
          final int g = int.parse(hex.substring(3, 5), radix: 16);
          return r > 200 && g > 200;
        }).toList();

        expect(
          isBlue.any((bool v) => v),
          isTrue,
          reason: 'Should find a blue-ish color',
        );
        expect(
          isYellow.any((bool v) => v),
          isTrue,
          reason: 'Should find a yellow-ish color',
        );
      });

      test('returns hex format #RRGGBB', () async {
        final File file = createBandedImage(<img.Color>[
          img.ColorRgb8(128, 64, 32),
        ]);
        final List<String> palette = await service.extractPalette(
          file,
          colorCount: 3,
        );

        expect(palette, isNotEmpty);
        for (final String hex in palette) {
          expect(hex, startsWith('#'));
          expect(hex, hasLength(7)); // #RRGGBB
          expect(() => int.parse(hex.substring(1), radix: 16), returnsNormally);
        }
      });

      test('returns empty for undecodable file', () async {
        final Directory tmpDir = Directory.systemTemp.createTempSync(
          'color_test_',
        );
        final File file = File('${tmpDir.path}/bad.png')
          ..writeAsBytesSync(<int>[1, 2, 3, 4]);

        // The image package may throw or return null — service handles both.
        final List<String> palette = await service.extractPalette(
          file,
          colorCount: 3,
        );
        expect(palette, isEmpty);
      });

      test('handles multi-color image with correct count', () async {
        final File file = createBandedImage(
          <img.Color>[
            img.ColorRgb8(255, 0, 0),
            img.ColorRgb8(0, 255, 0),
            img.ColorRgb8(0, 0, 255),
            img.ColorRgb8(255, 255, 0),
            img.ColorRgb8(255, 0, 255),
            img.ColorRgb8(0, 255, 255),
          ],
          width: 300,
          height: 300,
        );
        final List<String> palette = await service.extractPalette(file);

        expect(palette, hasLength(6));
      });
    });

    group('extractPaletteFromRegion', () {
      test('extracts colors from a sub-region', () async {
        // 4-quadrant image: red top-left, blue top-right, green bottom-left, white bottom-right
        final img.Image image = img.Image(width: 200, height: 200);
        for (int y = 0; y < 100; y++) {
          for (int x = 0; x < 100; x++) {
            image.setPixel(x, y, img.ColorRgb8(255, 0, 0));
          }
          for (int x = 100; x < 200; x++) {
            image.setPixel(x, y, img.ColorRgb8(0, 0, 255));
          }
        }
        for (int y = 100; y < 200; y++) {
          for (int x = 0; x < 100; x++) {
            image.setPixel(x, y, img.ColorRgb8(0, 255, 0));
          }
          for (int x = 100; x < 200; x++) {
            image.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          }
        }

        final Directory tmpDir = Directory.systemTemp.createTempSync(
          'color_region_',
        );
        final File file = File('${tmpDir.path}/quadrant.png')
          ..writeAsBytesSync(img.encodePng(image));

        // Extract from top-left quadrant: bbox [y1=0, x1=0, y2=500, x2=500]
        final List<String> palette = await service.extractPaletteFromRegion(
          file,
          <int>[0, 0, 500, 500],
          colorCount: 3,
        );

        expect(palette, isNotEmpty);
        // Should be dominantly red.
        final int r = int.parse(palette.first.substring(1, 3), radix: 16);
        expect(r, greaterThan(200));
      });

      test('returns empty for zero-size region', () async {
        final File file = createBandedImage(<img.Color>[
          img.ColorRgb8(128, 128, 128),
        ]);
        final List<String> palette = await service.extractPaletteFromRegion(
          file,
          <int>[100, 100, 100, 100], // zero-size bbox
        );
        expect(palette, isEmpty);
      });
    });

    group('hexAt', () {
      test('returns #RRGGBB of the pixel at (x, y)', () {
        final img.Image image = img.Image(width: 3, height: 3);
        image.setPixel(1, 1, img.ColorRgb8(255, 0, 128));

        expect(service.hexAt(image, 1, 1), '#FF0080');
      });

      test('clamps out-of-bounds coordinates to the nearest edge pixel', () {
        final img.Image image = img.Image(width: 2, height: 2);
        image.setPixel(0, 0, img.ColorRgb8(1, 2, 3));
        image.setPixel(1, 0, img.ColorRgb8(1, 2, 3));
        image.setPixel(0, 1, img.ColorRgb8(1, 2, 3));
        image.setPixel(1, 1, img.ColorRgb8(1, 2, 3));

        // (-5, 99) clamps to (0, 1).
        expect(service.hexAt(image, -5, 99), '#010203');
      });
    });
  });
}

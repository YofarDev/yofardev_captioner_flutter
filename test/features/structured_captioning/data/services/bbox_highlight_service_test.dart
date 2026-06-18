import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:yofardev_captioner/features/structured_captioning/data/services/bbox_highlight_service.dart';

void main() {
  late Directory tmpDir;
  late File imageFile;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('bbox_highlight_');
    // Solid 200x200 green PNG.
    final img.Image solid = img.Image(width: 200, height: 200);
    img.fill(solid, color: img.ColorRgb8(10, 200, 30));
    final String path = p.join(tmpDir.path, 'src.png');
    await File(path).writeAsBytes(img.encodePng(solid));
    imageFile = File(path);
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('BboxHighlightService', () {
    test('returns a decodable JPEG path with dimensions <= 1024', () async {
      final BboxHighlightService service = BboxHighlightService();
      // Bbox in the middle: [y1, x1, y2, x2] 0-1000.
      final String outPath = await service.renderHighlightedJpeg(
        imageFile,
        <int>[250, 250, 750, 750],
      );

      expect(File(outPath).existsSync(), isTrue);

      final Uint8List bytes = await File(outPath).readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(1024));
      expect(decoded.height, lessThanOrEqualTo(1024));

      // Cleanup contract.
      await service.cleanup(outPath);
      expect(File(outPath).existsSync(), isFalse);
    });

    test('throws ArgumentError when bbox has wrong arity', () async {
      final BboxHighlightService service = BboxHighlightService();
      await expectLater(
        service.renderHighlightedJpeg(imageFile, <int>[]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on degenerate bbox (zero area)', () async {
      final BboxHighlightService service = BboxHighlightService();
      await expectLater(
        service.renderHighlightedJpeg(imageFile, <int>[500, 500, 500, 500]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('downscales an image larger than 1024px', () async {
      // 1500x100 image.
      final img.Image big = img.Image(width: 1500, height: 100);
      img.fill(big, color: img.ColorRgb8(0, 0, 255));
      final String path = p.join(tmpDir.path, 'big.png');
      await File(path).writeAsBytes(img.encodePng(big));
      final BboxHighlightService service = BboxHighlightService();
      final String outPath = await service.renderHighlightedJpeg(
        File(path),
        <int>[100, 100, 900, 900],
      );
      final Uint8List bytes = await File(outPath).readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);
      expect(decoded!.width, lessThanOrEqualTo(1024));
      await service.cleanup(outPath);
    });

    test('cleanup is idempotent (safe to call twice)', () async {
      final BboxHighlightService service = BboxHighlightService();
      final String outPath = await service.renderHighlightedJpeg(
        imageFile,
        <int>[250, 250, 750, 750],
      );
      await service.cleanup(outPath);
      // Second call must not throw.
      await service.cleanup(outPath);
      expect(File(outPath).existsSync(), isFalse);
    });

    test('cleanup ignores a path that never existed', () async {
      final BboxHighlightService service = BboxHighlightService();
      // Must not throw.
      await service.cleanup('/nonexistent/path/nope_${DateTime.now().microsecondsSinceEpoch}.jpg');
    });

    test('handles portrait orientation (height > width)', () async {
      // 100x1500 portrait image.
      final img.Image portrait = img.Image(width: 100, height: 1500);
      img.fill(portrait, color: img.ColorRgb8(0, 128, 255));
      final String path = p.join(tmpDir.path, 'portrait.png');
      await File(path).writeAsBytes(img.encodePng(portrait));
      final BboxHighlightService service = BboxHighlightService();
      final String outPath = await service.renderHighlightedJpeg(
        File(path),
        <int>[100, 100, 900, 900],
      );
      final Uint8List bytes = await File(outPath).readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.height, lessThanOrEqualTo(1024));
      expect(decoded.width, lessThanOrEqualTo(1024));
      await service.cleanup(outPath);
    });
  });
}

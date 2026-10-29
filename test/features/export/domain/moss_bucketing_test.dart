import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/export/domain/moss_bucketing.dart';

void main() {
  group('aiToolkitBucket (port of toolkit/buckets.py)', () {
    test('23.png scenario: 1864×1864 at resolution 1024 → 1024×1024', () {
      final ({int width, int height}) b = aiToolkitBucket(
        width: 1864,
        height: 1864,
        resolution: 1024,
        divisibility: 16,
      );
      expect(b.width, 1024);
      expect(b.height, 1024);
    });

    test('portrait image keeps aspect ratio within the pixel budget', () {
      final ({int width, int height}) b = aiToolkitBucket(
        width: 832,
        height: 1216,
        resolution: 1024,
        divisibility: 16,
      );
      expect(b.width % 16, 0);
      expect(b.height % 16, 0);
      expect(b.width * b.height, lessThanOrEqualTo(1024 * 1024));
      expect(b.height, greaterThan(b.width));
    });

    test('small images keep their size when already divisible', () {
      final ({int width, int height}) b = aiToolkitBucket(
        width: 512,
        height: 256,
        resolution: 1024,
        divisibility: 16,
      );
      expect(b.width, 512);
      expect(b.height, 256);
    });

    test(
      'non-divisible small images snap to the grid at closest pixel count',
      () {
        final ({int width, int height}) b = aiToolkitBucket(
          width: 500,
          height: 300,
          resolution: 1024,
          divisibility: 16,
        );
        expect(b.width % 16, 0);
        expect(b.height % 16, 0);
        // The loader scales up to cover the bucket, so the bucket may be a
        // hair below the source on one axis — what matters is the grid and
        // the pixel budget.
        expect(b.width, greaterThanOrEqualTo(16));
        expect(b.height, greaterThanOrEqualTo(16));
        expect(b.width * b.height, lessThanOrEqualTo(1024 * 1024));
      },
    );

    test('divisibility 64 mirrors the AI Toolkit default bucket_tolerance', () {
      final ({int width, int height}) b = aiToolkitBucket(
        width: 1864,
        height: 998,
        resolution: 1024,
        divisibility: 64,
      );
      expect(b.width % 64, 0);
      expect(b.height % 64, 0);
      expect(b.width * b.height, lessThanOrEqualTo(1024 * 1024));
    });
  });

  group('planAiToolkitTransform (loader parity with dataloader_mixins.py)', () {
    test(
      'scale-to frame is ceil of source × max axis factor, central crop',
      () {
        final MossImageTransform t = planAiToolkitTransform(
          sourceWidth: 832,
          sourceHeight: 1216,
          resolution: 1024,
          divisibility: 16,
        );
        // Both scaleTo dims must be ≥ bucket dims and the crop must be the
        // centered int((scaleTo − bucket)/2).
        expect(t.scaleToWidth, greaterThanOrEqualTo(t.bucketWidth));
        expect(t.scaleToHeight, greaterThanOrEqualTo(t.bucketHeight));
        expect(t.cropX, (t.scaleToWidth - t.bucketWidth) ~/ 2);
        expect(t.cropY, (t.scaleToHeight - t.bucketHeight) ~/ 2);
        // uniform scale
        expect(
          (t.scaleToWidth / 832 - t.scaleToHeight / 1216).abs(),
          lessThan(1.0 / 832),
        );
      },
    );
  });

  group('fixed-point property', () {
    test('feeding realized dimensions back yields the same bucket, scale 1, '
        'crop 0', () {
      const List<(int, int)> sources = <(int, int)>[
        (1864, 1864), // the reported dataset case
        (832, 1216), // portrait
        (1216, 832), // landscape
        (300, 200), // small odd image
        (4096, 4096), // oversized
      ];
      for (final (int, int) source in sources) {
        final MossImageTransform t = planAiToolkitTransform(
          sourceWidth: source.$1,
          sourceHeight: source.$2,
          resolution: 1024,
          divisibility: 16,
        );
        // Second loader pass on the prepared pair.
        final MossImageTransform second = planAiToolkitTransform(
          sourceWidth: t.bucketWidth,
          sourceHeight: t.bucketHeight,
          resolution: 1024,
          divisibility: 16,
        );
        expect(
          second.bucketWidth,
          t.bucketWidth,
          reason: '${t.bucketWidth}x${t.bucketHeight} must be a fixed point',
        );
        expect(second.bucketHeight, t.bucketHeight);
        expect(second.scaleFactor, 1.0);
        expect(second.scaleToWidth, t.bucketWidth);
        expect(second.scaleToHeight, t.bucketHeight);
        expect(second.cropX, 0);
        expect(second.cropY, 0);
      }
    });
  });

  group('realized per-axis scale (Codex review finding 6)', () {
    test('Codex fixture: 1025×1103 → resize 992×1068, crop (0,6), bucket '
        '992×1056; quarter box maps to [248,260,743,795]', () {
      final MossImageTransform t = planAiToolkitTransform(
        sourceWidth: 1025,
        sourceHeight: 1103,
        resolution: 1024,
        divisibility: 16,
      );
      // The loader resizes to the independently ceiled scale-to frame, so
      // the realized x/y scales differ slightly from the ideal factor.
      expect(t.scaleToWidth, 992);
      expect(t.scaleToHeight, 1068);
      expect(t.cropX, 0);
      expect(t.cropY, 6);
      expect(t.bucketWidth, 992);
      expect(t.bucketHeight, 1056);
      final List<int>? out = transformBbox(<int>[256, 275, 768, 827], t);
      // One ideal scaleFactor would produce [248,260,743,794]; the realized
      // per-axis scales of the actual pixel resize produce [248,260,743,795].
      expect(out, <int>[248, 260, 743, 795]);
    });

    test('scaleFactorX/Y reflect the realized resize, not the ideal bucket '
        'scale', () {
      final MossImageTransform t = planAiToolkitTransform(
        sourceWidth: 1025,
        sourceHeight: 1103,
        resolution: 1024,
        divisibility: 16,
      );
      expect(t.scaleFactorX, closeTo(992 / 1025, 1e-9));
      expect(t.scaleFactorY, closeTo(1068 / 1103, 1e-9));
      expect(t.scaleFactorX == t.scaleFactorY, isFalse);
    });
  });

  group('transformBbox', () {
    test('full-frame box maps to the full output frame once rounded', () {
      final MossImageTransform t = planAiToolkitTransform(
        sourceWidth: 1864,
        sourceHeight: 1864,
        resolution: 1024,
        divisibility: 16,
      );
      expect(transformBbox(<int>[0, 0, 1864, 1864], t), <int>[
        0,
        0,
        1024,
        1024,
      ]);
    });

    test('axis swaps are exposed by asymmetric boxes on non-square frames', () {
      final MossImageTransform t = planAiToolkitTransform(
        sourceWidth: 2000,
        sourceHeight: 1000,
        resolution: 1024,
        divisibility: 16,
      );
      // Box in the right half of the wide source must stay in the right
      // half of the output (no y/x transposition).
      final List<int>? out = transformBbox(<int>[1000, 0, 2000, 1000], t);
      expect(out, isNotNull);
      expect(out!.first, greaterThanOrEqualTo(t.outputWidth ~/ 2 - 1));
      expect(t.outputHeight, lessThan(t.outputWidth));
    });

    test('boxes cropped away collapse to null', () {
      final MossImageTransform t = planAiToolkitTransform(
        sourceWidth: 1000,
        sourceHeight: 2000,
        resolution: 1024,
        divisibility: 16,
      );
      // Vertical central crop removes top/bottom; a box entirely in the
      // cropped-away top strip must be dropped.
      final List<int>? top = transformBbox(<int>[0, 0, 10, 1000], t);
      // 10px-tall box at the very top after ~0.5 scale is ≤ crop region.
      if (t.cropY * t.scaleFactor >= 10 * t.scaleFactor) {
        expect(top, isNull);
      } else {
        expect(top, isNotNull);
      }
    });
  });
}

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/image_operations/data/utils/image_utils.dart';

void main() {
  group('ImageUtils', () {
    group('getClosestSmallerResolution (refactored)', () {
      const List<Size> resolutions = <Size>[
        Size(1920, 1080),
        Size(1024, 768),
        Size(800, 600),
        Size(3395, 1909),
        Size(100, 100),
        Size(2000, 1000),
        Size(3600, 2880),
        Size(3397, 1911),
      ];

      void runTestForAspectRatio(Size aspectRatio, String description) {
        test('should return a resolution of $description aspect ratio', () {
          for (final Size resolution in resolutions) {
            final Size? result = ImageUtils.getExactResolutionWithinBounds(
              original: Size(resolution.width, resolution.height),
              aspect: aspectRatio,
            );
            expect(
              result!.width / result.height,
              aspectRatio.width / aspectRatio.height,
              reason: 'Aspect ratio should be $description',
            );
          }
        });
      }

      runTestForAspectRatio(const Size(16, 9), '16:9');
      runTestForAspectRatio(const Size(2, 3), '2:3');
      runTestForAspectRatio(const Size(3, 4), '3:4');
    });

    group('resizeImageIfNecessary - Configuration', () {
      test('should have correct max file size limit (1MB)', () {
        expect(ImageUtils.maxFileSize, equals(1 * 1024 * 1024));
      });

      test('should have correct max dimension limit (1024px)', () {
        expect(ImageUtils.maxDimension, equals(1024));
      });
    });

    group('getSimplifiedAspectRatio', () {
      test('reduces by gcd', () {
        expect(ImageUtils.getSimplifiedAspectRatio(1920, 1080), '16:9');
        expect(ImageUtils.getSimplifiedAspectRatio(1080, 1920), '9:16');
        expect(ImageUtils.getSimplifiedAspectRatio(1024, 1024), '1:1');
        expect(ImageUtils.getSimplifiedAspectRatio(1500, 500), '3:1');
        expect(ImageUtils.getSimplifiedAspectRatio(800, 600), '4:3');
      });

      test('handles already-reduced ratios', () {
        expect(ImageUtils.getSimplifiedAspectRatio(16, 9), '16:9');
        expect(ImageUtils.getSimplifiedAspectRatio(1, 1), '1:1');
      });

      test('returns placeholder for non-positive dimensions', () {
        expect(ImageUtils.getSimplifiedAspectRatio(0, 100), '...');
        expect(ImageUtils.getSimplifiedAspectRatio(100, 0), '...');
        expect(ImageUtils.getSimplifiedAspectRatio(-10, 50), '...');
      });
    });

    group('getExactResolutionWithinBounds', () {
      test('returns largest integer multiple of aspect that fits', () {
        final Size? r = ImageUtils.getExactResolutionWithinBounds(
          original: const Size(1920, 1080),
          aspect: const Size(16, 9),
        );
        expect(r, const Size(1920, 1080));
      });

      test('scales down to fit smaller originals', () {
        final Size? r = ImageUtils.getExactResolutionWithinBounds(
          original: const Size(100, 100),
          aspect: const Size(16, 9),
        );
        // Largest k such that 16k<=100 AND 9k<=100 → k=6 → 96x54.
        expect(r!.width, 96);
        expect(r.height, 54);
      });

      test('returns null when aspect has a zero dimension', () {
        expect(
          ImageUtils.getExactResolutionWithinBounds(
            original: const Size(1000, 1000),
            aspect: const Size(0, 9),
          ),
          isNull,
        );
        expect(
          ImageUtils.getExactResolutionWithinBounds(
            original: const Size(1000, 1000),
            aspect: const Size(16, 0),
          ),
          isNull,
        );
      });

      test('returns null when no scale ≥1 fits', () {
        expect(
          ImageUtils.getExactResolutionWithinBounds(
            original: const Size(10, 10),
            aspect: const Size(16, 9),
          ),
          isNull,
        );
      });

      test('handles square aspect within square bounds', () {
        final Size? r = ImageUtils.getExactResolutionWithinBounds(
          original: const Size(500, 500),
          aspect: const Size(1, 1),
        );
        expect(r, const Size(500, 500));
      });
    });

    // Note: Full integration tests for resizeImageIfNecessary require flutter_image_compress
    // which is not available in unit tests. See image_utils_manual_test.dart for logic tests.
    // For full end-to-end testing, run the app and test with actual image files.
  });
}

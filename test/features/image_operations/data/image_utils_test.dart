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

    // Note: Full integration tests for resizeImageIfNecessary require flutter_image_compress
    // which is not available in unit tests. See image_utils_manual_test.dart for logic tests.
    // For full end-to-end testing, run the app and test with actual image files.
  });
}

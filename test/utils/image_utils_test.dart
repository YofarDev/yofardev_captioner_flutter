import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/utils/image_utils.dart';

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
  });
}

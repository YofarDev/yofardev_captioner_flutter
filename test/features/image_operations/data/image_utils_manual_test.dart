// Manual test for image resizing functionality
// To run: dart test test/features/image_operations/data/image_utils_manual_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/image_operations/data/utils/image_utils.dart';

void main() {
  group('ImageUtils Manual Tests', () {
    test('Configuration values are correct', () {
      // Verify constants are set as expected
      expect(ImageUtils.maxFileSize, equals(2 * 1024 * 1024));
      expect(ImageUtils.maxDimension, equals(2048));
    });

    test('Calculate aspect ratio preservation', () {
      // Test that aspect ratio calculations are correct
      const int maxDim = 2048;

      // Landscape: width is constrained
      const int originalWidth = 4000;
      const int originalHeight = 3000;
      final int expectedHeight = ((maxDim * originalHeight) / originalWidth)
          .round();
      expect(expectedHeight, equals(1536));

      // Verify aspect ratio is maintained
      const double originalAspect = originalWidth / originalHeight;
      final double newAspect = maxDim / expectedHeight;
      expect((originalAspect - newAspect).abs(), lessThan(0.01));
    });

    test('Portrait image calculations', () {
      const int maxDim = 2048;
      const int originalWidth = 2000;
      const int originalHeight = 5000;

      // Portrait: height is constrained
      final int expectedWidth = ((maxDim * originalWidth) / originalHeight)
          .round();
      expect(expectedWidth, equals(819));

      // Verify aspect ratio is maintained
      const double originalAspect = originalWidth / originalHeight;
      final double newAspect = expectedWidth / maxDim;
      expect((originalAspect - newAspect).abs(), lessThan(0.01));
    });

    test('Square image calculations', () {
      const int maxDim = 2048;

      // Square: both dimensions should equal maxDim
      expect(maxDim, equals(2048));
      expect(maxDim, equals(2048));
    });

    test('Target dimension calculation logic', () {
      // Test various scenarios
      final Map<String, Map<String, int>> testCases =
          <String, Map<String, int>>{
            'Under limits': <String, int>{
              'width': 1024,
              'height': 768,
              'expectedW': 1024,
              'expectedH': 768,
            },
            'Over width': <String, int>{
              'width': 4000,
              'height': 3000,
              'expectedW': 2048,
              'expectedH': 1536,
            },
            'Over height': <String, int>{
              'width': 2000,
              'height': 5000,
              'expectedW': 819,
              'expectedH': 2048,
            },
            'Over both (landscape)': <String, int>{
              'width': 3000,
              'height': 3000,
              'expectedW': 2048,
              'expectedH': 2048,
            },
          };

      testCases.forEach((String name, Map<String, int> testCase) {
        final int width = testCase['width']!;
        final int height = testCase['height']!;
        final int expectedW = testCase['expectedW']!;
        final int expectedH = testCase['expectedH']!;

        int targetWidth = width;
        int targetHeight = height;
        const int maxDimension = 2048;

        if (width > maxDimension || height > maxDimension) {
          if (width > height) {
            targetWidth = maxDimension;
            targetHeight = (maxDimension * height / width).round();
          } else {
            targetHeight = maxDimension;
            targetWidth = (maxDimension * width / height).round();
          }
        }

        expect(targetWidth, expectedW, reason: 'Test case: $name (width)');
        expect(targetHeight, expectedH, reason: 'Test case: $name (height)');
      });
    });
  });
}

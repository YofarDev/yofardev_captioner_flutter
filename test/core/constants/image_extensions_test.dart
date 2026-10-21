import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/constants/image_extensions.dart';

void main() {
  test('isSupportedImageFile matches case-insensitively', () {
    expect(isSupportedImageFile('/a/b/c.JPG'), isTrue);
    expect(isSupportedImageFile('/a/b/c.jpeg'), isTrue);
    expect(isSupportedImageFile('/a/b/c.png'), isTrue);
    expect(isSupportedImageFile('/a/b/c.webp'), isTrue);
    expect(isSupportedImageFile('/a/b/c.gif'), isFalse);
    expect(isSupportedImageFile('/a/b/c'), isFalse);
  });
}

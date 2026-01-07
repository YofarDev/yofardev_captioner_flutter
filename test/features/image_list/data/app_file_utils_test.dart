import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';

void main() {
  group('AppFileUtils', () {
    late Directory tempDir;
    late AppFileUtils appFileUtils;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('app_file_utils_test');
      appFileUtils = AppFileUtils();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('removeImage should delete both image and caption file', () async {
      // Regression test for bug where caption files were not being deleted
      // 1. Create dummy image file
      final File imageFile = File(p.join(tempDir.path, 'test_image.jpg'));
      await imageFile.create();

      // 2. Create dummy caption file
      final File captionFile = File(p.join(tempDir.path, 'test_image.txt'));
      await captionFile.writeAsString('Test caption');

      // Ensure files exist
      expect(await imageFile.exists(), isTrue);
      expect(await captionFile.exists(), isTrue);

      // 3. Call removeImage
      await appFileUtils.removeImage(imageFile);

      // 4. Verify both files are deleted
      expect(await imageFile.exists(), isFalse, reason: 'Image file should be deleted');
      expect(await captionFile.exists(), isFalse, reason: 'Caption file should be deleted');
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
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
      expect(
        await imageFile.exists(),
        isFalse,
        reason: 'Image file should be deleted',
      );
      expect(
        await captionFile.exists(),
        isFalse,
        reason: 'Caption file should be deleted',
      );
    });

    test('duplicateImage should copy image file with _copy suffix', () async {
      // 1. Create original image file with content
      final File originalImageFile = File(
        p.join(tempDir.path, 'test_image.jpg'),
      );
      await originalImageFile.writeAsBytes(<int>[1, 2, 3, 4, 5]);

      // 2. Create AppImage with caption in database (not .txt file)
      const String originalCaption = 'Test caption content';
      final AppImage originalImage = AppImage(
        id: 'original-id',
        image: originalImageFile,
        captions: const <String, CaptionEntry>{
          'default': CaptionEntry(text: originalCaption),
        },
        size: await originalImageFile.length(),
        captionModel: 'test-model',
        captionTimestamp: DateTime(2025),
      );

      // 3. Duplicate the image
      final AppImage duplicatedImage = await appFileUtils.duplicateImage(
        originalImage,
      );

      // 4. Verify duplicated image file exists
      final File duplicatedImageFile = File(
        p.join(tempDir.path, 'test_image_copy.jpg'),
      );
      expect(
        await duplicatedImageFile.exists(),
        isTrue,
        reason: 'Duplicated image file should exist',
      );

      // 5. Verify duplicated image file has same content
      expect(
        await duplicatedImageFile.readAsBytes(),
        <int>[1, 2, 3, 4, 5],
        reason: 'Duplicated image should have same content',
      );

      // Note: With multi-category system, captions are stored in db.json,
      // not in individual .txt files, so we don't check for .txt file copying

      // 6. Verify duplicated AppImage has correct properties
      expect(
        duplicatedImage.id,
        isNot(equals(originalImage.id)),
        reason: 'Duplicated image should have new ID',
      );
      expect(
        duplicatedImage.caption,
        equals(originalCaption),
        reason: 'Duplicated image should have same caption',
      );
      expect(
        duplicatedImage.captionModel,
        equals('test-model'),
        reason: 'Duplicated image should preserve caption model',
      );
      expect(
        duplicatedImage.captionTimestamp,
        equals(DateTime(2025)),
        reason: 'Duplicated image should preserve caption timestamp',
      );
      expect(
        duplicatedImage.lastModified,
        isNotNull,
        reason: 'Duplicated image should have last modified timestamp',
      );
    });

    test(
      'duplicateImage should handle duplicate filenames by adding number suffix',
      () async {
        // 1. Create original image file
        final File originalImageFile = File(
          p.join(tempDir.path, 'test_image.jpg'),
        );
        await originalImageFile.writeAsBytes(<int>[1, 2, 3]);

        // 2. Create a file named test_image_copy.jpg to simulate a previous duplicate
        final File existingCopy = File(
          p.join(tempDir.path, 'test_image_copy.jpg'),
        );
        await existingCopy.writeAsBytes(<int>[1, 2, 3]);

        // 3. Create duplicate - should add _copy1 since _copy already exists
        final AppImage originalImage = AppImage(
          id: 'original-id',
          image: originalImageFile,
          captions: const <String, CaptionEntry>{},
        );
        final AppImage duplicatedImage = await appFileUtils.duplicateImage(
          originalImage,
        );

        // 4. Verify _copy1.jpg exists (not _copy2 because we start counter at 1)
        expect(
          await File(p.join(tempDir.path, 'test_image_copy1.jpg')).exists(),
          isTrue,
          reason:
              'Duplicate should have _copy1 suffix when _copy already exists',
        );

        // 5. Verify the duplicated image points to the correct file
        expect(
          duplicatedImage.image.path,
          contains('test_image_copy1.jpg'),
          reason: 'Duplicated image should have _copy1 suffix',
        );
      },
    );

    test(
      'duplicateImage should work when caption file does not exist',
      () async {
        // 1. Create original image file without caption
        final File originalImageFile = File(
          p.join(tempDir.path, 'no_caption.jpg'),
        );
        await originalImageFile.writeAsBytes(<int>[1, 2, 3]);

        // 2. Create AppImage with empty caption
        final AppImage originalImage = AppImage(
          id: 'original-id',
          image: originalImageFile,
          captions: const <String, CaptionEntry>{},
        );

        // 3. Duplicate the image
        final AppImage duplicatedImage = await appFileUtils.duplicateImage(
          originalImage,
        );

        // 4. Verify duplicated image file exists and has correct path
        expect(
          duplicatedImage.image.path,
          contains('no_caption_copy.jpg'),
          reason: 'Duplicated image should have _copy suffix',
        );
        final File duplicatedImageFile = File(
          p.join(tempDir.path, 'no_caption_copy.jpg'),
        );
        expect(
          await duplicatedImageFile.exists(),
          isTrue,
          reason: 'Duplicated image file should exist',
        );

        // 5. Verify caption file was not created
        final File duplicatedCaptionFile = File(
          p.join(tempDir.path, 'no_caption_copy.txt'),
        );
        expect(
          await duplicatedCaptionFile.exists(),
          isFalse,
          reason:
              'Caption file should not be created if original has no caption',
        );
      },
    );
  });
}

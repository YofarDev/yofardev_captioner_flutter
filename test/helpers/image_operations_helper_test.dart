import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_captioner/helpers/image_operations_helper.dart';

void main() {
  group('ImageOperationsHelper', () {
    late ImageOperationsHelper imageOperationsHelper;
    late Directory tempDir;

    setUp(() async {
      imageOperationsHelper = ImageOperationsHelper();
      tempDir = await Directory.systemTemp.createTemp('image_ops_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'renameAllFiles shuffles captions when some images lack captions',
      () async {
        // 1. Create a scenario with a mix of images with and without captions
        await File(p.join(tempDir.path, '01_image.jpg')).create();
        await File(
          p.join(tempDir.path, '01_image.txt'),
        ).writeAsString('caption for 01');
        await File(p.join(tempDir.path, '02_image.jpg')).create();
        await File(p.join(tempDir.path, '03_image.jpg')).create();
        await File(
          p.join(tempDir.path, '03_image.txt'),
        ).writeAsString('caption for 03');

        // 2. Call the rename function
        await imageOperationsHelper.renameAllFiles(tempDir.path);

        // 3. Verify the CORRECT behavior
        final List<FileSystemEntity> files = tempDir.listSync();
        final List<String> fileNames = files
            .map((FileSystemEntity f) => p.basename(f.path))
            .toList();

        // Check that the images are renamed correctly
        expect(fileNames, containsAll(<dynamic>['01.jpg', '02.jpg', '03.jpg']));

        // Check that captions are correctly named
        expect(fileNames, contains('01.txt'));
        expect(
          fileNames,
          isNot(contains('02.txt')),
          reason:
              '02.txt should not be created as 02_image.jpg has no caption.',
        );
        expect(
          fileNames,
          contains('03.txt'),
          reason: '03.txt should be created for 03_image.jpg with its caption.',
        );

        // Check the content of the captions
        final String caption1Content = await File(
          p.join(tempDir.path, '01.txt'),
        ).readAsString();
        expect(caption1Content, 'caption for 01');

        final String caption3Content = await File(
          p.join(tempDir.path, '03.txt'),
        ).readAsString();
        expect(caption3Content, 'caption for 03');
      },
    );
  });
}

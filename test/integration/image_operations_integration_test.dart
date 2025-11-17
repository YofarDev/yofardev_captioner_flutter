import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/helpers/image_operations_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ImageOperationsHelper Integration Test', () {
    late ImageOperationsHelper imageOperationsHelper;
    late Directory tempDir;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      imageOperationsHelper = ImageOperationsHelper();
      tempDir = await Directory.systemTemp.createTemp(
        'image_ops_integration_test',
      );
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tempDir.delete(recursive: true);
    });

    test(
      'renameAllFiles works correctly with real file system operations',
      () async {
        // 1. Create a mix of existing and new files
        const int existingFileCount = 50;
        for (int i = 1; i <= existingFileCount; i++) {
          final String paddedIndex = i.toString().padLeft(2, '0');
          await File(p.join(tempDir.path, '$paddedIndex.jpg')).create();
          await File(p.join(tempDir.path, '$paddedIndex.txt')).create();
        }

        await File(p.join(tempDir.path, 'z_new_image.jpg')).create();
        await File(p.join(tempDir.path, 'z_new_image.txt')).create();
        await File(p.join(tempDir.path, 'a_new_image.png')).create();

        // 2. Call the function to be tested
        await imageOperationsHelper.renameAllFiles(tempDir.path);

        // 3. Verify the results
        final List<FileSystemEntity> files = tempDir.listSync().toList();
        final List<String> fileNames =
            files.map((FileSystemEntity e) => p.basename(e.path)).toList()
              ..sort();
        // Check the newly added files
        expect(fileNames, contains('51.png'));
        expect(fileNames, contains('52.jpg'));

        // Verify the total file count
        // 52 images + 51 captions
        expect(files.length, 103);

        // Ensure old names are gone
        expect(fileNames, isNot(contains('z_new_image.jpg')));
        expect(fileNames, isNot(contains('z_new_image.txt')));
        expect(fileNames, isNot(contains('a_new_image.png')));
      },
    );
  });
}

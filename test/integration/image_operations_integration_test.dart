import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:yofardev_captioner/helpers/image_operations_helper.dart';
import 'package:yofardev_captioner/logic/images_list/image_list_cubit.dart';
import 'package:yofardev_captioner/models/app_image.dart';
import 'package:yofardev_captioner/utils/app_file_utils.dart';

import 'image_operations_integration_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit, AppFileUtils])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ImageOperationsHelper Integration Test', () {
    late ImageOperationsHelper imageOperationsHelper;
    late MockImageListCubit mockImageListCubit;
    late MockAppFileUtils mockAppFileUtils;
    late Directory tempDir;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      mockImageListCubit = MockImageListCubit();
      mockAppFileUtils = MockAppFileUtils();

      when(mockAppFileUtils.compareNatural(any, any)).thenAnswer((
        Invocation inv,
      ) {
        final String a = inv.positionalArguments[0] as String;
        final String b = inv.positionalArguments[1] as String;
        return a.compareTo(b);
      });

      imageOperationsHelper = ImageOperationsHelper(
        imageListCubit: mockImageListCubit,
        fileUtils: mockAppFileUtils,
      );

      tempDir = await Directory.systemTemp.createTemp(
        'image_ops_integration_test',
      );
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tempDir.delete(recursive: true);
    });

    test(
      'renameAllFiles renames physical image files and triggers folder pick',
      () async {
        // 1. Create dummy image files
        final File imageFile1 = File(p.join(tempDir.path, 'image_c.jpg'))
          ..createSync();
        final File imageFile2 = File(p.join(tempDir.path, 'image_a.png'))
          ..createSync();
        final File imageFile3 = File(p.join(tempDir.path, 'image_b.jpeg'))
          ..createSync();

        // 2. Set up mock ImageListCubit state
        final List<AppImage> initialImages = <AppImage>[
          AppImage(
            id: const Uuid().v4(),
            image: imageFile1,
            caption: 'Caption C',
          ),
          AppImage(
            id: const Uuid().v4(),
            image: imageFile2,
            caption: 'Caption A',
          ),
          AppImage(
            id: const Uuid().v4(),
            image: imageFile3,
            caption: 'Caption B',
          ),
        ];

        when(mockImageListCubit.state).thenReturn(
          ImageListState(folderPath: tempDir.path, images: initialImages),
        );

        // 3. Mock onFolderPicked to do nothing but complete
        when(
          mockImageListCubit.onFolderPicked(tempDir.path),
        ).thenAnswer((_) async {});

        // 4. Call the method under test
        await imageOperationsHelper.renameAllFiles(tempDir.path);

        // 5. Verify physical files are renamed
        final List<String> renamedFileNames = tempDir
            .listSync()
            .whereType<File>()
            .map((File f) => p.basename(f.path))
            .toList();

        // Expect the sorted and padded names
        expect(renamedFileNames, contains('01.png'));
        expect(renamedFileNames, contains('02.jpeg'));
        expect(renamedFileNames, contains('03.jpg'));
        expect(renamedFileNames, hasLength(3));

        // 6. Verify that onFolderPicked was called to refresh the state and DB
        verify(mockImageListCubit.onFolderPicked(tempDir.path)).called(1);

        // Ensure old file names are gone
        expect(
          tempDir.listSync().whereType<File>().map(
            (File e) => p.basename(e.path),
          ),
          isNot(contains('image_a.png')),
        );
        expect(
          tempDir.listSync().whereType<File>().map(
            (File e) => p.basename(e.path),
          ),
          isNot(contains('image_b.jpeg')),
        );
        expect(
          tempDir.listSync().whereType<File>().map(
            (File e) => p.basename(e.path),
          ),
          isNot(contains('image_c.jpg')),
        );
      },
    );
  });
}

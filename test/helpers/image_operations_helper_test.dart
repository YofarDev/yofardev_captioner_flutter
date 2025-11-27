import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:yofardev_captioner/helpers/image_operations_helper.dart';
import 'package:yofardev_captioner/logic/images_list/image_list_cubit.dart';
import 'package:yofardev_captioner/models/app_image.dart';
import 'package:yofardev_captioner/utils/app_file_utils.dart';

import 'image_operations_helper_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit, AppFileUtils])
void main() {
  group('ImageOperationsHelper', () {
    late ImageOperationsHelper imageOperationsHelper;
    late MockImageListCubit mockImageListCubit;
    late MockAppFileUtils mockAppFileUtils;
    late Directory tempDir;

    setUp(() async {
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

      tempDir = await Directory.systemTemp.createTemp('image_ops_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'renameAllFiles renames image files and triggers folder pick',
      () async {
        // Setup mock state for ImageListCubit
        final File image1 = File(p.join(tempDir.path, 'image_c.jpg'))
          ..createSync();
        final File image2 = File(p.join(tempDir.path, 'image_a.png'))
          ..createSync();
        final File image3 = File(p.join(tempDir.path, 'image_b.jpeg'))
          ..createSync();

        final List<AppImage> initialImages = <AppImage>[
          AppImage(id: const Uuid().v4(), image: image1, caption: 'Caption C'),
          AppImage(id: const Uuid().v4(), image: image2, caption: 'Caption A'),
          AppImage(id: const Uuid().v4(), image: image3, caption: 'Caption B'),
        ];

        when(mockImageListCubit.state).thenReturn(
          ImageListState(folderPath: tempDir.path, images: initialImages),
        );
        when(
          mockImageListCubit.onFolderPicked(tempDir.path),
        ).thenAnswer((_) async {});

        // Call the method under test
        await imageOperationsHelper.renameAllFiles(tempDir.path);

        // Verify that physical files are renamed
        final List<String> renamedFileNames = tempDir
            .listSync()
            .whereType<File>()
            .map((File f) => p.basename(f.path))
            .toList();

        expect(renamedFileNames, contains('01.png'));
        expect(renamedFileNames, contains('02.jpeg'));
        expect(renamedFileNames, contains('03.jpg'));
        expect(renamedFileNames, hasLength(3)); // Only image files

        // Verify that onFolderPicked was called to refresh the state and DB
        verify(mockImageListCubit.onFolderPicked(tempDir.path)).called(1);
      },
    );
  });
}

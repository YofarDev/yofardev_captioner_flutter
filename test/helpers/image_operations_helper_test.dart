import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_data.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_database.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/helpers/image_operations_helper.dart';

import 'image_operations_helper_test.mocks.dart';

/// Generates mocks for:
/// - [ImageListCubit]: To simulate state changes and interaction with the UI layer.
/// - [AppFileUtils]: To mock low-level file system and database operations.
@GenerateNiceMocks(<MockSpec<Object>>[
  MockSpec<ImageListCubit>(),
  MockSpec<AppFileUtils>(),
])
void main() {
  /// Test group for [ImageOperationsHelper] logic.
  /// Primarily focuses on batch file operations like renaming and ensuring
  /// sidecar files (captions) are handled correctly.
  group('ImageOperationsHelper', () {
    late ImageOperationsHelper imageOperationsHelper;
    late MockImageListCubit mockImageListCubit;
    late MockAppFileUtils mockAppFileUtils;

    /// A temporary directory created for each test to ensure file operations
    /// are sandboxed and do not affect the actual file system.
    late Directory tempDir;

    /// An in-memory representation of the JSON database to mock read/write operations.
    late CaptionDatabase inMemoryDb;

    setUp(() async {
      mockImageListCubit = MockImageListCubit();
      mockAppFileUtils = MockAppFileUtils();
      inMemoryDb = CaptionDatabase(
        categories: <String>['default'],
        images: <CaptionData>[],
      );

      // Mock natural sort comparison to behave like standard string comparison for tests
      when(mockAppFileUtils.compareNatural(any, any)).thenAnswer((
        Invocation inv,
      ) {
        final String a = inv.positionalArguments[0] as String;
        final String b = inv.positionalArguments[1] as String;
        return a.compareTo(b);
      });

      // Mock reading the DB: Return a copy of the in-memory DB
      when(mockAppFileUtils.readDb(any)).thenAnswer((_) async {
        return CaptionDatabase.fromJson(inMemoryDb.toJson());
      });

      // Mock writing the DB: Update the in-memory DB variable
      when(mockAppFileUtils.writeDb(any, any)).thenAnswer((
        Invocation inv,
      ) async {
        inMemoryDb = inv.positionalArguments[1] as CaptionDatabase;
      });

      imageOperationsHelper = ImageOperationsHelper(
        imageListCubit: mockImageListCubit,
        fileUtils: mockAppFileUtils,
      );

      // Create a unique temporary directory for this test run
      tempDir = await Directory.systemTemp.createTemp('image_ops_test');
    });

    tearDown(() async {
      // Clean up physical files after test finishes
      await tempDir.delete(recursive: true);
    });

    /// Test Case: **renameAllFiles renames files and preserves captions**
    ///
    /// **Scenario:**
    /// We have 3 images (a.png, 01.jpeg, c.jpg) and 3 corresponding text files.
    ///
    /// **Expected Outcome:**
    /// 1. Files are renamed sequentially (02.png, 03.jpg).
    /// 2. Text files are renamed to match their images (01.txt, etc).
    /// 3. The content of the text files is preserved.
    /// 4. The database update method is called with the correct mapping.
    test(
      'renameAllFiles renames files and preserves captions - simplified',
      () async {
        // ---------------------------------------------------------------------
        // 1. Arrange (Setup)
        // ---------------------------------------------------------------------

        // Create physical image files in the temp directory
        final File imageAFile = File(p.join(tempDir.path, 'a.png'))
          ..createSync();
        final File imageBFile = File(p.join(tempDir.path, '01.jpeg'))
          ..createSync();
        final File imageCFile = File(p.join(tempDir.path, 'c.jpg'))
          ..createSync();

        // Create physical caption files with specific content
        final File captionAFile = File(p.join(tempDir.path, 'a.txt'))
          ..writeAsStringSync('caption a');
        final File captionBFile = File(p.join(tempDir.path, '01.txt'))
          ..writeAsStringSync('caption b');
        final File captionCFile = File(p.join(tempDir.path, 'c.txt'))
          ..writeAsStringSync('caption c');

        // Mock the Cubit state to contain these files
        final List<AppImage> initialImages = <AppImage>[
          AppImage(
            id: const Uuid().v4(),
            image: imageCFile,
            captions: <String, CaptionEntry>{
              'default': CaptionEntry(text: await captionCFile.readAsString()),
            },
          ),
          AppImage(
            id: const Uuid().v4(),
            image: imageAFile,
            captions: <String, CaptionEntry>{
              'default': CaptionEntry(text: await captionAFile.readAsString()),
            },
          ),
          AppImage(
            id: const Uuid().v4(),
            image: imageBFile,
            captions: <String, CaptionEntry>{
              'default': CaptionEntry(text: await captionBFile.readAsString()),
            },
          ),
        ];

        when(mockImageListCubit.state).thenReturn(
          ImageListState(folderPath: tempDir.path, images: initialImages),
        );

        // Mock onFolderPicked to do nothing for this specific test
        when(mockImageListCubit.onFolderPicked(any)).thenAnswer((_) async {});

        // ---------------------------------------------------------------------
        // 2. Act
        // ---------------------------------------------------------------------
        await imageOperationsHelper.renameAllFiles(tempDir.path);

        // ---------------------------------------------------------------------
        // 3. Assert
        // ---------------------------------------------------------------------

        // Define the expected mapping: Original Filename -> New Filename
        // Note: Logic usually sorts alphabetically before renaming
        final Map<String, String> expectedRenameMap = <String, String>{
          'a.png': '02.png',
          '01.jpeg': '01.jpeg',
          'c.jpg': '03.jpg',
        };

        // Verify updateDbForRename was called with that mapping
        verify(
          mockAppFileUtils.updateDbForRename(expectedRenameMap, tempDir.path),
        ).called(1);

        // Define expected renamed file paths
        final File renamedImageA = File(p.join(tempDir.path, '02.png'));
        final File renamedImageB = File(p.join(tempDir.path, '01.jpeg'));
        final File renamedImageC = File(p.join(tempDir.path, '03.jpg'));

        // Verify physical image files exist with new names
        expect(await renamedImageA.exists(), isTrue);
        expect(await renamedImageB.exists(), isTrue);
        expect(await renamedImageC.exists(), isTrue);

        final File renamedCaptionA = File(p.join(tempDir.path, '02.txt'));
        final File renamedCaptionB = File(p.join(tempDir.path, '01.txt'));
        final File renamedCaptionC = File(p.join(tempDir.path, '03.txt'));

        // Verify physical text files exist with new names
        expect(await renamedCaptionA.exists(), isTrue);
        expect(await renamedCaptionB.exists(), isTrue);
        expect(await renamedCaptionC.exists(), isTrue);

        // Verify content was not lost during rename
        expect(await renamedCaptionA.readAsString(), 'caption a');
        expect(await renamedCaptionB.readAsString(), 'caption b');
        expect(await renamedCaptionC.readAsString(), 'caption c');
      },
    );

    /// Test Case: **renameAllFiles renames image files and triggers folder pick**
    ///
    /// **Scenario:**
    /// Mixed extensions. Files exist.
    ///
    /// **Expected Outcome:**
    /// 1. Physical files are renamed to 01, 02, 03.
    /// 2. [ImageListCubit.onFolderPicked] is triggered to refresh the UI state.
    test(
      'renameAllFiles renames image files and triggers folder pick',
      () async {
        // ---------------------------------------------------------------------
        // 1. Arrange
        // ---------------------------------------------------------------------
        final File image1 = File(p.join(tempDir.path, 'image_c.jpg'))
          ..createSync();
        final File image2 = File(p.join(tempDir.path, 'image_a.png'))
          ..createSync();
        final File image3 = File(p.join(tempDir.path, 'image_b.jpeg'))
          ..createSync();

        final List<AppImage> initialImages = <AppImage>[
          AppImage(
            id: const Uuid().v4(),
            image: image1,
            captions: const <String, CaptionEntry>{
              'default': CaptionEntry(text: 'Caption C'),
            },
          ),
          AppImage(
            id: const Uuid().v4(),
            image: image2,
            captions: const <String, CaptionEntry>{
              'default': CaptionEntry(text: 'Caption A'),
            },
          ),
          AppImage(
            id: const Uuid().v4(),
            image: image3,
            captions: const <String, CaptionEntry>{
              'default': CaptionEntry(text: 'Caption B'),
            },
          ),
        ];

        when(mockImageListCubit.state).thenReturn(
          ImageListState(folderPath: tempDir.path, images: initialImages),
        );

        // Stub the reload method
        when(
          mockImageListCubit.onFolderPicked(tempDir.path),
        ).thenAnswer((_) async {});

        // ---------------------------------------------------------------------
        // 2. Act
        // ---------------------------------------------------------------------
        await imageOperationsHelper.renameAllFiles(tempDir.path);

        // ---------------------------------------------------------------------
        // 3. Assert
        // ---------------------------------------------------------------------

        // Get list of physical files remaining in directory
        final List<String> renamedFileNames = tempDir
            .listSync()
            .whereType<File>()
            .map((File f) => p.basename(f.path))
            .toList();

        // Verify the presence of renamed files
        expect(renamedFileNames, contains('01.png'));
        expect(renamedFileNames, contains('02.jpeg'));
        expect(renamedFileNames, contains('03.jpg'));
        expect(renamedFileNames, hasLength(3)); // Ensure only 3 files exist

        // Verify that the logic asked the Cubit to refresh the view
        verify(mockImageListCubit.onFolderPicked(tempDir.path)).called(1);
      },
    );
  });
}

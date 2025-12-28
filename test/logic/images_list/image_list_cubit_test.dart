import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';
import 'package:yofardev_captioner/logic/images_list/image_list_cubit.dart';
import 'package:yofardev_captioner/models/app_image.dart';
import 'package:yofardev_captioner/utils/app_file_utils.dart';

import 'image_list_cubit_test.mocks.dart';

@GenerateMocks(<Type>[AppFileUtils])
void main() {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    const MethodChannel channel = MethodChannel('window_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });
  group('ImageListCubit', () {
    late ImageListCubit imageListCubit;
    late MockAppFileUtils mockAppFileUtils;

    setUp(() {
      mockAppFileUtils = MockAppFileUtils();
      imageListCubit = ImageListCubit(fileUtils: mockAppFileUtils);
    });

    final AppImage testImage = AppImage(
      id: const Uuid().v4(),
      image: File('test/test_resources/test_image.jpg'),
      caption: 'test caption',
      size: 123,
    );

    blocTest<ImageListCubit, ImageListState>(
      'emits new state and calls file utils when removeImage is called',
      build: () {
        when(
          mockAppFileUtils.removeImage(any),
        ).thenAnswer((_) => Future<void>.value());
        return imageListCubit;
      },
      seed: () => ImageListState(images: <AppImage>[testImage]),
      act: (ImageListCubit cubit) => cubit.removeImage(0),
      expect: () => <TypeMatcher<ImageListState>>[
        isA<ImageListState>().having(
          (ImageListState state) => state.images,
          'images',
          isEmpty,
        ),
      ],
      verify: (_) {
        verify(mockAppFileUtils.removeImage(testImage.image)).called(1);
      },
    );

    blocTest<ImageListCubit, ImageListState>(
      'onFolderPicked loads images when folder changes',
      build: () {
        when(
          mockAppFileUtils.onFolderPicked(any),
        ).thenAnswer((_) async => <AppImage>[testImage]);
        return imageListCubit;
      },
      act: (ImageListCubit cubit) => cubit.onFolderPicked('/new/path'),
      expect: () => <TypeMatcher<ImageListState>>[
        isA<ImageListState>()
            .having(
              (ImageListState s) => s.folderPath,
              'folderPath',
              '/new/path',
            )
            .having(
              (ImageListState s) => s.images,
              'images',
              isEmpty,
            ), // Initial empty state
        isA<ImageListState>()
            .having(
              (ImageListState s) => s.folderPath,
              'folderPath',
              '/new/path',
            )
            .having(
              (ImageListState s) => s.images,
              'images',
              hasLength(1),
            ), // Loaded images
      ],
      verify: (_) {
        verify(mockAppFileUtils.onFolderPicked('/new/path')).called(1);
      },
    );

    blocTest<ImageListCubit, ImageListState>(
      'onFolderPicked does NOTHING when folder is same and force is false',
      build: () {
        return imageListCubit;
      },
      seed: () => const ImageListState(folderPath: '/existing/path'),
      act: (ImageListCubit cubit) => cubit.onFolderPicked('/existing/path'),
      expect: () => <ImageListState>[], // No state emitted
      verify: (_) {
        verifyNever(mockAppFileUtils.onFolderPicked(any));
      },
    );

    blocTest<ImageListCubit, ImageListState>(
      'onFolderPicked reloads images when folder is same AND force is TRUE',
      build: () {
        when(
          mockAppFileUtils.onFolderPicked(any),
        ).thenAnswer((_) async => <AppImage>[testImage]);
        return imageListCubit;
      },
      seed: () => ImageListState(folderPath: '/existing/path', images: <AppImage>[testImage]),
      act: (ImageListCubit cubit) => cubit.onFolderPicked('/existing/path', force: true),
      expect: () => <TypeMatcher<ImageListState>>[
        isA<ImageListState>()
             .having((ImageListState s) => s.images, 'images', isEmpty), // Reset images
        isA<ImageListState>()
            .having((ImageListState s) => s.images, 'images', hasLength(1)), // Reloaded
      ],
      verify: (_) {
        verify(mockAppFileUtils.onFolderPicked('/existing/path')).called(1);
      },
    );
  });
}

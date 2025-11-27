import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
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
  });
}

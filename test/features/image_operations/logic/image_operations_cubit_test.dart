import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/image_operations/logic/image_operations_cubit.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/helpers/image_operations_helper.dart';

import 'image_operations_cubit_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit, ImageOperationsHelper])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageOperationsCubit', () {
    late ImageOperationsCubit imageOperationsCubit;
    late MockImageListCubit mockImageListCubit;

    setUp(() {
      mockImageListCubit = MockImageListCubit();
      imageOperationsCubit = ImageOperationsCubit(mockImageListCubit);
    });

    tearDown(() {
      imageOperationsCubit.close();
    });

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'should start with initial state',
      build: () => imageOperationsCubit,
      expect: () => const ImageOperationsState(),
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'should not rename if folder path is null',
      setUp: () {
        when(mockImageListCubit.state).thenReturn(
          const ImageListState(folderPath: null),
        );
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) => cubit.renameAllFiles(),
      expect: () => const ImageOperationsState(),
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'should not export if folder path is null',
      setUp: () {
        when(mockImageListCubit.state).thenReturn(
          const ImageListState(folderPath: null),
        );
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) => cubit.exportAsArchive(),
      expect: () => const ImageOperationsState(),
    );

    test('should instantiate correctly', () {
      expect(imageOperationsCubit, isNotNull);
      expect(mockImageListCubit, isNotNull);
    });
  });
}

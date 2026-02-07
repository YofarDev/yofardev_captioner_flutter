import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_operations/logic/image_operations_cubit.dart';
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

    test('should start with initial state', () {
      expect(imageOperationsCubit.state, const ImageOperationsState());
      expect(imageOperationsCubit.state.status, ImageOperationsStatus.initial);
      expect(imageOperationsCubit.state.progress, 0.0);
    });

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'should not rename if folder path is null',
      setUp: () {
        when(mockImageListCubit.state).thenReturn(const ImageListState());
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) => cubit.renameAllFiles(),
      expect: () =>
          <ImageOperationsState>[], // No state emitted when folder is null
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'should not export if folder path is null',
      setUp: () {
        when(mockImageListCubit.state).thenReturn(const ImageListState());
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) => cubit.exportAsArchive(
        '/fake/path',
        <AppImage>[],
        'default',
      ),
      expect: () =>
          <ImageOperationsState>[], // No state emitted when folder is null
    );

    test('should instantiate correctly', () {
      expect(imageOperationsCubit, isNotNull);
      expect(mockImageListCubit, isNotNull);
    });
  });
}

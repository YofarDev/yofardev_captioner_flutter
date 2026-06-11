import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_operations/logic/image_operations_cubit.dart';
import 'package:yofardev_captioner/helpers/image_operations_helper.dart';

import 'image_operations_cubit_test.mocks.dart';

/// Minimal BuildContext fake for unit tests.
class FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

@GenerateMocks(<Type>[ImageListCubit, ImageOperationsHelper])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppImage makeImage({required String id, required String path}) {
    return AppImage(
      id: id,
      image: File(path),
      captions: const <String, CaptionEntry>{},
    );
  }

  group('ImageOperationsCubit', () {
    late ImageOperationsCubit imageOperationsCubit;
    late MockImageListCubit mockImageListCubit;
    late MockImageOperationsHelper mockHelper;

    setUp(() {
      mockImageListCubit = MockImageListCubit();
      mockHelper = MockImageOperationsHelper();
      imageOperationsCubit = ImageOperationsCubit(
        mockImageListCubit,
        helper: mockHelper,
      );
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
      'renameAllFiles does nothing when folder path is null',
      setUp: () {
        when(mockImageListCubit.state).thenReturn(const ImageListState());
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) => cubit.renameAllFiles(),
      expect: () => <ImageOperationsState>[],
      verify: (_) {
        verifyNever(mockHelper.renameAllFiles(any));
      },
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'renameAllFiles calls helper and refreshes folder',
      setUp: () {
        when(
          mockImageListCubit.state,
        ).thenReturn(const ImageListState(folderPath: '/test/folder'));
        when(mockImageListCubit.onFolderPicked(any)).thenAnswer((_) async {});
        when(mockHelper.renameAllFiles(any)).thenAnswer((_) async {});
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) => cubit.renameAllFiles(),
      expect: () => <ImageOperationsState>[],
      verify: (_) {
        verify(mockHelper.renameAllFiles('/test/folder')).called(1);
        verify(
          mockImageListCubit.onFolderPicked('/test/folder', force: true),
        ).called(1);
      },
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'exportAsArchive does nothing when folder path is null',
      setUp: () {
        when(mockImageListCubit.state).thenReturn(const ImageListState());
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) =>
          cubit.exportAsArchive('/fake/path', <AppImage>[], 'default'),
      expect: () => <ImageOperationsState>[],
      verify: (_) {
        verifyNever(mockHelper.exportAsArchive(any, any, any));
      },
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'exportAsArchive calls helper with fresh state',
      setUp: () {
        final AppImage img = makeImage(id: '1', path: '/f/a.jpg');
        when(mockImageListCubit.state).thenReturn(
          ImageListState(folderPath: '/test/folder', images: <AppImage>[img]),
        );
        when(mockImageListCubit.onFolderPicked(any)).thenAnswer((_) async {});
        when(
          mockHelper.exportAsArchive(any, any, any),
        ).thenAnswer((_) async {});
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) =>
          cubit.exportAsArchive('/test/folder', <AppImage>[], 'default'),
      expect: () => <ImageOperationsState>[],
      verify: (_) {
        verify(
          mockHelper.exportAsArchive('/test/folder', any, 'default'),
        ).called(1);
      },
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'convertAllImages emits progress and success states',
      setUp: () {
        final AppImage img = makeImage(id: '1', path: '/f/a.jpg');
        when(mockImageListCubit.state).thenReturn(
          ImageListState(folderPath: '/test/folder', images: <AppImage>[img]),
        );
        when(
          mockHelper.convertAllImages(
            format: anyNamed('format'),
            quality: anyNamed('quality'),
            state: anyNamed('state'),
          ),
        ).thenAnswer((_) {
          return Stream<ImageListState>.fromIterable(<ImageListState>[
            ImageListState(images: <AppImage>[img]),
          ]);
        });
        when(mockImageListCubit.saveChanges()).thenAnswer((_) async {});
        when(
          mockImageListCubit.onFolderPicked(any, force: anyNamed('force')),
        ).thenAnswer((_) async {});
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) =>
          cubit.convertAllImages(format: 'png', quality: 90),
      expect: () => <TypeMatcher<ImageOperationsState>>[
        // InProgress + progress 0
        isA<ImageOperationsState>()
            .having(
              (ImageOperationsState s) => s.status,
              'status',
              ImageOperationsStatus.inProgress,
            )
            .having((ImageOperationsState s) => s.progress, 'progress', 0.0),
        // Progress 1/1 = 1.0
        isA<ImageOperationsState>().having(
          (ImageOperationsState s) => s.progress,
          'progress',
          1.0,
        ),
        // Success
        isA<ImageOperationsState>().having(
          (ImageOperationsState s) => s.status,
          'status',
          ImageOperationsStatus.success,
        ),
      ],
      verify: (_) {
        verify(mockImageListCubit.saveChanges()).called(1);
        verify(
          mockImageListCubit.onFolderPicked('/test/folder', force: true),
        ).called(1);
      },
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'cropCurrentImage emits nothing when helper returns null',
      setUp: () {
        when(
          mockImageListCubit.state,
        ).thenReturn(const ImageListState(folderPath: '/test'));
        when(
          mockHelper.cropCurrentImage(any, any),
        ).thenAnswer((_) async => null);
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) =>
          cubit.cropCurrentImage(FakeBuildContext()),
      expect: () => <ImageOperationsState>[],
      verify: (_) {
        verifyNever(mockImageListCubit.emit(any));
      },
    );
  });
}

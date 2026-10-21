import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/image_operations/presentation/bloc/image_operations_cubit.dart';
import 'package:yofardev_captioner/helpers/image_operations_helper.dart';

import 'image_operations_cubit_test.mocks.dart';

/// Minimal BuildContext fake for unit tests.
class FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

@GenerateMocks(<Type>[CaptionSessionService, ImageOperationsHelper])
void main() {
  provideDummy<Either<Failure, void>>(const Right<Failure, void>(null));

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
    late MockCaptionSessionService mockSession;
    late MockImageOperationsHelper mockHelper;

    setUp(() {
      mockSession = MockCaptionSessionService();
      mockHelper = MockImageOperationsHelper();
      imageOperationsCubit = ImageOperationsCubit(
        mockSession,
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
        when(mockSession.state).thenReturn(const ImageListState());
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
          mockSession.state,
        ).thenReturn(const ImageListState(folderPath: '/test/folder'));
        when(mockSession.onFolderPicked(any)).thenAnswer((_) async {});
        when(
          mockHelper.renameAllFiles(any),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
      },
      build: () => imageOperationsCubit,
      act: (ImageOperationsCubit cubit) => cubit.renameAllFiles(),
      expect: () => <ImageOperationsState>[],
      verify: (_) {
        verify(mockHelper.renameAllFiles('/test/folder')).called(1);
        // Two forced refreshes: one before the rename (so it reconciles with
        // current disk state, e.g. images deleted outside the app) and one
        // after to reflect the new names. Dropping the pre-refresh breaks this.
        verify(
          mockSession.onFolderPicked('/test/folder', force: true),
        ).called(2);
      },
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'exportAsArchive does nothing when folder path is null',
      setUp: () {
        when(mockSession.state).thenReturn(const ImageListState());
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
        when(mockSession.state).thenReturn(
          ImageListState(folderPath: '/test/folder', images: <AppImage>[img]),
        );
        when(mockSession.onFolderPicked(any)).thenAnswer((_) async {});
        when(
          mockHelper.exportAsArchive(any, any, any),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
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
        when(mockSession.state).thenReturn(
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
        when(mockSession.saveChanges()).thenAnswer((_) async {});
        when(
          mockSession.onFolderPicked(any, force: anyNamed('force')),
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
        verify(mockSession.saveChanges()).called(1);
        verify(
          mockSession.onFolderPicked('/test/folder', force: true),
        ).called(1);
      },
    );

    test(
      'convertAllImages stops consuming and does not throw after close',
      () async {
        // The loop reads _session.state.images once for the total — stub it with
        // two images so the math matches the two stream events below.
        when(mockSession.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              makeImage(id: '1', path: '/f/a.jpg'),
              makeImage(id: '2', path: '/f/b.jpg'),
            ],
            folderPath: '/folder',
          ),
        );
        final StreamController<ImageListState> controller =
            StreamController<ImageListState>.broadcast();
        when(
          mockHelper.convertAllImages(
            format: 'png',
            quality: 90,
            state: anyNamed('state'),
          ),
        ).thenAnswer((_) => controller.stream);

        final ImageOperationsCubit cubit = ImageOperationsCubit(
          mockSession,
          helper: mockHelper,
        );
        // convertAllImages returns void (fire-and-forget); its async errors
        // surface in the test zone.
        cubit.convertAllImages(format: 'png', quality: 90);
        controller.add(const ImageListState()); // first event consumed
        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        controller.add(const ImageListState()); // must be ignored after close
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, isNot(ImageOperationsStatus.success));
        await controller.close();
      },
    );

    test(
      'convertAllImages does not throw when close lands during saveChanges',
      () async {
        when(mockSession.state).thenReturn(
          ImageListState(
            images: <AppImage>[makeImage(id: '1', path: '/f/a.jpg')],
            folderPath: '/folder',
          ),
        );
        when(
          mockHelper.convertAllImages(
            format: 'png',
            quality: 90,
            state: anyNamed('state'),
          ),
        ).thenAnswer(
          (_) => Stream<ImageListState>.fromIterable(<ImageListState>[
            const ImageListState(),
          ]),
        );
        // The cubit is closed inside the save window, i.e. between
        // `await _session.saveChanges()` starting and the success emit.
        final ImageOperationsCubit cubit = ImageOperationsCubit(
          mockSession,
          helper: mockHelper,
        );
        final Completer<void> saveCompleter = Completer<void>();
        when(mockSession.saveChanges()).thenAnswer((_) async {
          await cubit.close();
          saveCompleter.complete();
        });
        when(
          mockSession.onFolderPicked(any, force: anyNamed('force')),
        ).thenAnswer((_) async {});

        // convertAllImages returns void (fire-and-forget); its async errors
        // surface in the test zone. Wait for the save window to pass.
        cubit.convertAllImages(format: 'png', quality: 90);
        await saveCompleter.future.timeout(const Duration(seconds: 5));
        // Let the post-save microtasks (success emit + delayed restart) run;
        // an emit on the closed cubit would throw an unhandled StateError.
        for (int i = 0; i < 3; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        verify(mockSession.saveChanges()).called(1);
        expect(cubit.state.status, isNot(ImageOperationsStatus.success));
      },
    );

    blocTest<ImageOperationsCubit, ImageOperationsState>(
      'cropCurrentImage emits nothing when helper returns null',
      setUp: () {
        when(
          mockSession.state,
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
        verifyNever(mockSession.replaceState(any));
      },
    );
  });
}

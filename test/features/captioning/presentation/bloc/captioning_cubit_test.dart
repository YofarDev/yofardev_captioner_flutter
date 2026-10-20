import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/captioning_repository.dart';
import 'package:yofardev_captioner/features/captioning/domain/models/caption_options.dart';
import 'package:yofardev_captioner/features/captioning/presentation/bloc/captioning_cubit.dart';
import 'package:yofardev_captioner/features/image_list/domain/models/image_list_state.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/caption_session_service.dart';

import 'captioning_cubit_test.mocks.dart';

@GenerateMocks(<Type>[CaptioningRepository])
/// Hand-rolled fake of the [CaptionFileStore] port (ported from
/// caption_session_service_test.dart) — records db writes, serves empty
/// folders, never touches the filesystem beyond in-memory state.
class _FakeFileStore implements CaptionFileStore {
  final List<CaptionDatabase> writtenDbs = <CaptionDatabase>[];

  @override
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath) =>
      Future<
        Either<
          Failure,
          ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
        >
      >.value(
        Right<
          Failure,
          ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
        >((
          images: <AppImage>[],
          db: CaptionDatabase(
            categories: <String>['default'],
            images: <CaptionData>[],
          ),
          dbFailure: null,
        )),
      );

  @override
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath) async =>
      Right<Failure, CaptionDatabase>(
        CaptionDatabase(
          categories: <String>['default'],
          images: <CaptionData>[],
        ),
      );

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {
    writtenDbs.add(db);
  }

  @override
  Future<void> removeImage(File imageFile) async {}

  @override
  Future<void> writeCaptionFiles(
    String folderPath,
    List<AppImage> images,
    String category,
    String format,
  ) async {}

  @override
  Future<void> removeCaptionFiles(
    String folderPath,
    List<AppImage> images,
  ) async {}

  @override
  Future<AppImage> duplicateImage(AppImage originalImage) async =>
      originalImage;

  @override
  int compareNatural(String a, String b) => a.compareTo(b);

  @override
  Future<List<AppImage>> getImagesSize(List<AppImage> images) async => images;

  @override
  Future<AppImage> getSingleImageSize(AppImage image) async => image;
}

/// Filter engine that returns exactly the images it was configured with, so
/// scopeToFiltered tests can stub the filtered set deterministically.
class _StubFilterEngine implements CaptionFilterEngine {
  /// When null (the default), the engine passes images through unchanged —
  /// matching unfiltered sessions. Tests stub [filtered] to scope a run.
  List<AppImage>? filtered;

  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) => filtered ?? images;
}

void main() {
  // Mockito cannot synthesize Either dummies for the new signatures.
  provideDummy<Either<Failure, AppImage>>(
    Right<Failure, AppImage>(
      AppImage(
        id: 'dummy',
        image: File('dummy.png'),
        captions: const <String, CaptionEntry>{},
      ),
    ),
  );
  group('CaptioningCubit', () {
    late CaptioningCubit captioningCubit;
    late CaptionSessionService session;
    late _FakeFileStore store;
    late _StubFilterEngine filterEngine;
    late MockCaptioningRepository mockCaptioningRepository;

    /// Seeds the session state the way the owning cubit's tests used to seed
    /// the mock (adopt: no snapshot emitted, state visible immediately).
    void seed(ImageListState state) => session.adopt(state);

    setUp(() {
      store = _FakeFileStore();
      filterEngine = _StubFilterEngine();
      session = CaptionSessionService(
        fileStore: store,
        filterEngine: filterEngine,
      );
      mockCaptioningRepository = MockCaptioningRepository();
      captioningCubit = CaptioningCubit(
        session,
        captioningRepository: mockCaptioningRepository,
      );
    });

    tearDown(() {
      captioningCubit.close();
      session.dispose();
    });

    test('initial state is initial', () {
      expect(captioningCubit.state.status, CaptioningStatus.initial);
      expect(captioningCubit.state.progress, 0.0);
      expect(captioningCubit.state.isCancelling, false);
    });

    test('runCaptioner applies delay between requests', () {
      fakeAsync((FakeAsync async) {
        final AppImage image1 = AppImage(
          id: '1',
          image: File('path/to/img1.jpg'),
          captions: const <String, CaptionEntry>{},
        );
        final AppImage image2 = AppImage(
          id: '2',
          image: File('path/to/img2.jpg'),
          captions: const <String, CaptionEntry>{},
        );
        final List<AppImage> images = <AppImage>[image1, image2];
        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test LLM',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
          apiKey: 'key',
          delay: 1000,
        );

        seed(ImageListState(images: images, folderPath: '/tmp'));

        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (Invocation invocation) async => Right<Failure, AppImage>(
            invocation.positionalArguments[1] as AppImage,
          ),
        );

        captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Test Prompt',
          option: CaptionOptions.all,
        );

        expect(captioningCubit.state.status, CaptioningStatus.inProgress);

        async.flushMicrotasks();
        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image1,
            'Test Prompt',
            cancelToken: anyNamed('cancelToken'),
          ),
        ).called(1);

        async.elapse(const Duration(milliseconds: 500));
        verifyNever(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image2,
            'Test Prompt',
            cancelToken: anyNamed('cancelToken'),
          ),
        );

        async.elapse(const Duration(milliseconds: 501));
        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image2,
            'Test Prompt',
            cancelToken: anyNamed('cancelToken'),
          ),
        ).called(1);
      });
    });

    test('runCaptioner succeeds with zero images', () async {
      seed(const ImageListState(folderPath: '/tmp'));

      final LlmConfig llmConfig = LlmConfig(
        id: '1',
        name: 'Test',
        model: 'gpt-4',
        providerType: LlmProviderType.remote,
      );

      await captioningCubit.runCaptioner(
        llm: llmConfig,
        prompt: 'Prompt',
        option: CaptionOptions.all,
      );

      expect(captioningCubit.state.status, CaptioningStatus.success);
      expect(captioningCubit.state.totalImages, 0);
      verifyNever(
        mockCaptioningRepository.captionImage(
          any,
          any,
          any,
          cancelToken: anyNamed('cancelToken'),
        ),
      );
    });

    test('runCaptioner captions only current image', () async {
      final AppImage image1 = AppImage(
        id: '1',
        image: File('img1.jpg'),
        captions: const <String, CaptionEntry>{},
      );
      final AppImage image2 = AppImage(
        id: '2',
        image: File('img2.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      seed(
        ImageListState(
          images: <AppImage>[image1, image2],
          folderPath: '/tmp',
          currentImageId: '2',
        ),
      );
      when(
        mockCaptioningRepository.captionImage(
          any,
          any,
          any,
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer(
        (Invocation invocation) async => Right<Failure, AppImage>(
          invocation.positionalArguments[1] as AppImage,
        ),
      );

      final LlmConfig llmConfig = LlmConfig(
        id: '1',
        name: 'Test',
        model: 'gpt-4',
        providerType: LlmProviderType.remote,
      );

      await captioningCubit.runCaptioner(
        llm: llmConfig,
        prompt: 'Prompt',
        option: CaptionOptions.current,
      );

      verify(
        mockCaptioningRepository.captionImage(
          llmConfig,
          image2,
          'Prompt',
          cancelToken: anyNamed('cancelToken'),
        ),
      ).called(1);
      verifyNever(
        mockCaptioningRepository.captionImage(
          llmConfig,
          image1,
          'Prompt',
          cancelToken: anyNamed('cancelToken'),
        ),
      );
      expect(captioningCubit.state.status, CaptioningStatus.success);
    });

    test('runCaptioner captions only images with missing captions', () async {
      final AppImage withCaption = AppImage(
        id: '1',
        image: File('img1.jpg'),
        captions: const <String, CaptionEntry>{
          'default': CaptionEntry(text: 'existing caption'),
        },
      );
      final AppImage withoutCaption = AppImage(
        id: '2',
        image: File('img2.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      seed(
        ImageListState(
          images: <AppImage>[withCaption, withoutCaption],
          folderPath: '/tmp',
        ),
      );
      when(
        mockCaptioningRepository.captionImage(
          any,
          any,
          any,
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer(
        (Invocation invocation) async => Right<Failure, AppImage>(
          invocation.positionalArguments[1] as AppImage,
        ),
      );

      final LlmConfig llmConfig = LlmConfig(
        id: '1',
        name: 'Test',
        model: 'gpt-4',
        providerType: LlmProviderType.remote,
      );

      await captioningCubit.runCaptioner(
        llm: llmConfig,
        prompt: 'Prompt',
        option: CaptionOptions.missing,
      );

      verify(
        mockCaptioningRepository.captionImage(
          llmConfig,
          withoutCaption,
          'Prompt',
          cancelToken: anyNamed('cancelToken'),
        ),
      ).called(1);
      verifyNever(
        mockCaptioningRepository.captionImage(
          llmConfig,
          withCaption,
          'Prompt',
          cancelToken: anyNamed('cancelToken'),
        ),
      );
    });

    test('runCaptioner handles errors and reports failure', () async {
      final AppImage image = AppImage(
        id: '1',
        image: File('img.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
      when(
        mockCaptioningRepository.captionImage(
          any,
          any,
          any,
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer(
        (_) async => const Left<Failure, AppImage>(
          Failure.serverError(message: 'API error'),
        ),
      );

      final LlmConfig llmConfig = LlmConfig(
        id: '1',
        name: 'Test',
        model: 'gpt-4',
        providerType: LlmProviderType.remote,
      );

      await captioningCubit.runCaptioner(
        llm: llmConfig,
        prompt: 'Prompt',
        option: CaptionOptions.all,
      );

      expect(captioningCubit.state.status, CaptioningStatus.failure);
      expect(
        captioningCubit.state.error,
        contains('The server encountered an error'),
      );
      expect(captioningCubit.state.processedImages, 0);
    });

    test(
      'runCaptioner keeps using the start category after the active tab changes',
      () async {
        final AppImage image1 = AppImage(
          id: '1',
          image: File('img1.jpg'),
          captions: const <String, CaptionEntry>{},
        );
        final AppImage image2 = AppImage(
          id: '2',
          image: File('img2.jpg'),
          captions: const <String, CaptionEntry>{},
        );

        String activeCategory = 'caption1';
        void updateSessionState() => seed(
          ImageListState(
            images: <AppImage>[image1, image2],
            folderPath: '/tmp',
            activeCategory: activeCategory,
          ),
        );
        updateSessionState();

        final List<String> categoriesPassed = <String>[];
        final Completer<Either<Failure, AppImage>> call1 =
            Completer<Either<Failure, AppImage>>();
        final Completer<Either<Failure, AppImage>> call2 =
            Completer<Either<Failure, AppImage>>();
        int callIndex = 0;
        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            category: anyNamed('category'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer((Invocation inv) {
          categoriesPassed.add(
            inv.namedArguments[const Symbol('category')] as String,
          );
          final Completer<Either<Failure, AppImage>> c = callIndex == 0
              ? call1
              : call2;
          callIndex++;
          return c.future;
        });

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        final Future<void> run = captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Prompt',
          option: CaptionOptions.all,
        );

        // Let the run reach the first captionImage await.
        await Future<void>.delayed(Duration.zero);
        expect(categoriesPassed, <String>['caption1']);

        // User switches category tab mid-run.
        activeCategory = 'caption2';
        updateSessionState();

        call1.complete(
          Right<Failure, AppImage>(
            image1.copyWith(
              captions: const <String, CaptionEntry>{
                'caption1': CaptionEntry(text: 'c1'),
              },
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Second image must STILL use the start category (caption1).
        expect(categoriesPassed, <String>['caption1', 'caption1']);

        call2.complete(
          Right<Failure, AppImage>(
            image2.copyWith(
              captions: const <String, CaptionEntry>{
                'caption1': CaptionEntry(text: 'c2'),
              },
            ),
          ),
        );
        await run;

        expect(captioningCubit.state.status, CaptioningStatus.success);
      },
    );

    test('cancelCaptioning sets isCancelling', () {
      captioningCubit.cancelCaptioning();

      expect(captioningCubit.state.isCancelling, true);
    });

    group('rewriteCaption', () {
      test('updates current image caption with rewritten text', () async {
        final AppImage image = AppImage(
          id: '1',
          image: File('img.jpg'),
          captions: const <String, CaptionEntry>{
            'default': CaptionEntry(text: 'A person stands.'),
          },
        );

        seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
        when(mockCaptioningRepository.rewriteCaption(any, any, any)).thenAnswer(
          (Invocation inv) async {
            final AppImage img = inv.positionalArguments[1] as AppImage;
            return Right<Failure, AppImage>(
              img.copyWith(
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(
                    text: 'A young woman stands.',
                    isEdited: true,
                  ),
                },
              ),
            );
          },
        );

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        await captioningCubit.rewriteCaption(
          llm: llmConfig,
          instructions: 'make the person a young woman',
        );

        final AppImage passed = session.state.images.single;
        expect(passed.captions['default']?.text, 'A young woman stands.');
        expect(passed.captions['default']?.isEdited, true);
      });

      test('throws when no current image is selected', () async {
        seed(const ImageListState(folderPath: '/tmp'));
        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        final String? failure = await captioningCubit.rewriteCaption(
          llm: llmConfig,
          instructions: 'x',
        );
        expect(failure, 'No image selected');
        verifyNever(mockCaptioningRepository.rewriteCaption(any, any, any));
      });

      test(
        'propagates repository errors and does not update the image',
        () async {
          final AppImage image = AppImage(
            id: '1',
            image: File('img.jpg'),
            captions: const <String, CaptionEntry>{
              'default': CaptionEntry(text: 'A person stands.'),
            },
          );

          seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
          when(
            mockCaptioningRepository.rewriteCaption(any, any, any),
          ).thenAnswer(
            (_) async =>
                const Left<Failure, AppImage>(FailureServer(message: 'x')),
          );

          final LlmConfig llmConfig = LlmConfig(
            id: '1',
            name: 'Test',
            model: 'gpt-4',
            providerType: LlmProviderType.remote,
          );

          final String? failure = await captioningCubit.rewriteCaption(
            llm: llmConfig,
            instructions: 'make it better',
          );
          expect(
            failure,
            'The server encountered an error. Please try again later.',
          );
          expect(
            session.state.images.single.captions['default']?.text,
            'A person stands.',
          );
        },
      );
    });

    test('clearErrors resets status to initial', () async {
      final AppImage image = AppImage(
        id: '1',
        image: File('img.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
      when(
        mockCaptioningRepository.captionImage(
          any,
          any,
          any,
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer(
        (_) async =>
            const Left<Failure, AppImage>(Failure.serverError(message: 'fail')),
      );

      final LlmConfig llmConfig = LlmConfig(
        id: '1',
        name: 'Test',
        model: 'gpt-4',
        providerType: LlmProviderType.remote,
      );

      await captioningCubit.runCaptioner(
        llm: llmConfig,
        prompt: 'Prompt',
        option: CaptionOptions.all,
      );
      expect(captioningCubit.state.status, CaptioningStatus.failure);

      captioningCubit.clearErrors();

      expect(captioningCubit.state.status, CaptioningStatus.initial);
      // The staleness fix under test: the error is cleared, not left set.
      expect(captioningCubit.state.error, isNull);
    });

    test('runCaptioner emits progress updates', () async {
      final AppImage image1 = AppImage(
        id: '1',
        image: File('img1.jpg'),
        captions: const <String, CaptionEntry>{},
      );
      final AppImage image2 = AppImage(
        id: '2',
        image: File('img2.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      seed(
        ImageListState(images: <AppImage>[image1, image2], folderPath: '/tmp'),
      );
      when(
        mockCaptioningRepository.captionImage(
          any,
          any,
          any,
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer(
        (Invocation invocation) async => Right<Failure, AppImage>(
          invocation.positionalArguments[1] as AppImage,
        ),
      );

      final LlmConfig llmConfig = LlmConfig(
        id: '1',
        name: 'Test',
        model: 'gpt-4',
        providerType: LlmProviderType.remote,
      );

      await captioningCubit.runCaptioner(
        llm: llmConfig,
        prompt: 'Prompt',
        option: CaptionOptions.all,
      );

      expect(captioningCubit.state.status, CaptioningStatus.success);
      expect(captioningCubit.state.processedImages, 2);
      expect(captioningCubit.state.totalImages, 2);
      expect(captioningCubit.state.progress, 1.0);
    });

    test(
      'runCaptioner skips already-caption-edited images for all option',
      () async {
        final AppImage edited = AppImage(
          id: '1',
          image: File('img1.jpg'),
          captions: const <String, CaptionEntry>{},
          isCaptionEdited: true,
        );
        final AppImage notEdited = AppImage(
          id: '2',
          image: File('img2.jpg'),
          captions: const <String, CaptionEntry>{},
        );

        seed(
          ImageListState(
            images: <AppImage>[edited, notEdited],
            folderPath: '/tmp',
          ),
        );
        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (Invocation invocation) async => Right<Failure, AppImage>(
            invocation.positionalArguments[1] as AppImage,
          ),
        );

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        await captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Prompt',
          option: CaptionOptions.all,
        );

        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            notEdited,
            'Prompt',
            cancelToken: anyNamed('cancelToken'),
          ),
        ).called(1);
        verifyNever(
          mockCaptioningRepository.captionImage(
            llmConfig,
            edited,
            'Prompt',
            cancelToken: anyNamed('cancelToken'),
          ),
        );
      },
    );

    test(
      'runCaptioner with scopeToFiltered true captions only filtered images',
      () {
        fakeAsync((FakeAsync async) {
          final AppImage image1 = AppImage(
            id: '1',
            image: File('path/to/img1.jpg'),
            captions: const <String, CaptionEntry>{},
          );
          final AppImage image2 = AppImage(
            id: '2',
            image: File('path/to/img2.jpg'),
            captions: const <String, CaptionEntry>{},
          );
          final List<AppImage> allImages = <AppImage>[image1, image2];

          seed(ImageListState(images: allImages, folderPath: '/tmp'));
          // Stub the filtered set: only image1 is in it.
          filterEngine.filtered = <AppImage>[image1];

          when(
            mockCaptioningRepository.captionImage(
              any,
              any,
              any,
              cancelToken: anyNamed('cancelToken'),
            ),
          ).thenAnswer(
            (Invocation invocation) async => Right<Failure, AppImage>(
              invocation.positionalArguments[1] as AppImage,
            ),
          );

          final LlmConfig llmConfig = LlmConfig(
            id: '1',
            name: 'Test LLM',
            model: 'gpt-4',
            providerType: LlmProviderType.remote,
            apiKey: 'key',
          );

          captioningCubit.runCaptioner(
            llm: llmConfig,
            prompt: 'Test Prompt',
            option: CaptionOptions.all,
            scopeToFiltered: true,
          );

          async.flushMicrotasks();

          verify(
            mockCaptioningRepository.captionImage(
              llmConfig,
              image1,
              'Test Prompt',
              cancelToken: anyNamed('cancelToken'),
            ),
          ).called(1);
          verifyNever(
            mockCaptioningRepository.captionImage(
              llmConfig,
              image2,
              any,
              cancelToken: anyNamed('cancelToken'),
            ),
          );
        });
      },
    );

    test('runCaptioner scoped + all re-captions edited images (drops guard)', () {
      fakeAsync((FakeAsync async) {
        final AppImage editedImage = AppImage(
          id: '1',
          image: File('path/to/img1.jpg'),
          captions: const <String, CaptionEntry>{},
          isCaptionEdited: true,
        );

        seed(
          ImageListState(images: <AppImage>[editedImage], folderPath: '/tmp'),
        );
        filterEngine.filtered = <AppImage>[editedImage];

        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (Invocation invocation) async => Right<Failure, AppImage>(
            invocation.positionalArguments[1] as AppImage,
          ),
        );

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test LLM',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
          apiKey: 'key',
        );

        captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Test Prompt',
          option: CaptionOptions.all,
          scopeToFiltered: true,
        );

        async.flushMicrotasks();

        // Edited image MUST be captioned when scoped (proves the guard was dropped).
        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            editedImage,
            'Test Prompt',
            cancelToken: anyNamed('cancelToken'),
          ),
        ).called(1);
      });
    });

    test('runCaptioner unscoped + all still skips edited images', () {
      fakeAsync((FakeAsync async) {
        final AppImage editedImage = AppImage(
          id: '1',
          image: File('path/to/img1.jpg'),
          captions: const <String, CaptionEntry>{},
          isCaptionEdited: true,
        );

        seed(
          ImageListState(images: <AppImage>[editedImage], folderPath: '/tmp'),
        );

        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (Invocation invocation) async => Right<Failure, AppImage>(
            invocation.positionalArguments[1] as AppImage,
          ),
        );

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test LLM',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
          apiKey: 'key',
        );

        captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Test Prompt',
          option: CaptionOptions.all,
          // scopeToFiltered defaults to false
        );

        async.flushMicrotasks();

        verifyNever(
          mockCaptioningRepository.captionImage(
            llmConfig,
            editedImage,
            any,
            cancelToken: anyNamed('cancelToken'),
          ),
        );
      });
    });

    test(
      'runCaptioner appends JSON context to prompt when jsonContextCategory has a caption',
      () async {
        final AppImage image = AppImage(
          id: '1',
          image: File('img.jpg'),
          captions: const <String, CaptionEntry>{
            'json': CaptionEntry(text: '{"scene": "forest"}'),
          },
        );

        seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            category: anyNamed('category'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (Invocation invocation) async => Right<Failure, AppImage>(
            invocation.positionalArguments[1] as AppImage,
          ),
        );

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        await captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Describe this image.',
          option: CaptionOptions.all,
          jsonContextCategory: 'json',
        );

        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image,
            'Describe this image.\n\n'
            'Existing structured analysis of this image (JSON), use as reference:\n'
            '{"scene": "forest"}',
            category: anyNamed('category'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).called(1);
      },
    );

    test(
      'runCaptioner uses plain prompt when jsonContextCategory caption is empty',
      () async {
        final AppImage image = AppImage(
          id: '1',
          image: File('img.jpg'),
          captions: const <String, CaptionEntry>{
            'json': CaptionEntry(text: ''),
          },
        );

        seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            category: anyNamed('category'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (Invocation invocation) async => Right<Failure, AppImage>(
            invocation.positionalArguments[1] as AppImage,
          ),
        );

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        await captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Describe this image.',
          option: CaptionOptions.all,
          jsonContextCategory: 'json',
        );

        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image,
            'Describe this image.',
            category: anyNamed('category'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).called(1);
      },
    );

    test(
      'runCaptioner without jsonContextCategory passes prompt unchanged',
      () async {
        final AppImage image = AppImage(
          id: '1',
          image: File('img.jpg'),
          captions: const <String, CaptionEntry>{
            'json': CaptionEntry(text: '{"scene": "forest"}'),
          },
        );

        seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            category: anyNamed('category'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (Invocation invocation) async => Right<Failure, AppImage>(
            invocation.positionalArguments[1] as AppImage,
          ),
        );

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        await captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Describe this image.',
          option: CaptionOptions.all,
        );

        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image,
            'Describe this image.',
            category: anyNamed('category'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).called(1);
      },
    );
  });
}

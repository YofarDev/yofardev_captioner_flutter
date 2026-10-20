import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_options.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/caption_session_service.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_state.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/logic/structured_captioning_cubit.dart';

import 'structured_captioning_cubit_test.mocks.dart';

@GenerateMocks(<Type>[StructuredCaptionRepository])
/// Hand-rolled fake of the [CaptionFileStore] port (ported from
/// caption_session_service_test.dart) — records db writes, serves empty
/// folders, never touches the filesystem beyond in-memory state.
class _FakeFileStore implements CaptionFileStore {
  @override
  Future<List<AppImage>> onFolderPicked(String folderPath) =>
      Future<List<AppImage>>.value(<AppImage>[]);

  @override
  Future<CaptionDatabase> readDb(String folderPath) async =>
      CaptionDatabase(categories: <String>['default'], images: <CaptionData>[]);

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {}

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

/// Filter engine that passes images through unchanged by default; tests stub
/// [filtered] to scope a run.
class _StubFilterEngine implements CaptionFilterEngine {
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
  IdeogramCaption fakeCaption() => const IdeogramCaption(
    highLevelDescription: 'desc',
    styleDescription: IdeogramStyleDescription(
      aesthetics: 'a',
      lighting: 'l',
      medium: 'photograph',
      colorPalette: <String>[],
    ),
    compositionalDeconstruction: IdeogramCompositionalDeconstruction(
      background: '',
      elements: <IdeogramElement>[],
    ),
  );

  LlmConfig llmConfig() => LlmConfig(
    id: '1',
    name: 'Test',
    model: 'gpt-4',
    providerType: LlmProviderType.remote,
  );

  group('StructuredCaptioningCubit', () {
    late StructuredCaptioningCubit cubit;
    late CaptionSessionService session;
    late _StubFilterEngine filterEngine;
    late MockStructuredCaptionRepository mockRepository;

    /// Seeds the session state (adopt: no snapshot emitted, state visible
    /// immediately). Guidance is disabled by default so `guidanceFor`
    /// returns '' — keeping the omit-the-named-arg stub/verify matchers valid.
    void seed(ImageListState state) => session.adopt(state);

    setUp(() {
      filterEngine = _StubFilterEngine();
      session = CaptionSessionService(
        fileStore: _FakeFileStore(),
        filterEngine: filterEngine,
      );
      mockRepository = MockStructuredCaptionRepository();
      cubit = StructuredCaptioningCubit(session, repository: mockRepository);
    });

    tearDown(() {
      cubit.close();
      session.dispose();
    });

    test('initial state is initial', () {
      expect(cubit.state.status, StructuredCaptioningStatus.initial);
      expect(cubit.state.progress, 0.0);
      expect(cubit.state.isCancelling, false);
      expect(cubit.state.error, isNull);
    });

    test('fails when current image selected but none displayed', () async {
      seed(const ImageListState(folderPath: '/tmp'));

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.current,
      );

      expect(cubit.state.status, StructuredCaptioningStatus.failure);
      expect(cubit.state.error, 'No image selected');
      verifyNever(
        mockRepository.generateStructuredCaption(
          any,
          any,
          onProgress: anyNamed('onProgress'),
        ),
      );
    });

    test('captions only the current image', () async {
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
        mockRepository.generateStructuredCaption(
          any,
          any,
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).thenAnswer((_) async => fakeCaption());

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.current,
      );

      verify(
        mockRepository.generateStructuredCaption(
          any,
          argThat(equals(image2.image)),
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).called(1);
      expect(cubit.state.status, StructuredCaptioningStatus.success);
    });

    test('missing option filters to images with empty caption text', () async {
      // ponytail: text must be a complete Ideogram JSON so the cubit's
      // missing-filter (empty OR non-ideogram OR empty HLD) excludes it.
      final AppImage withCaption = AppImage(
        id: '1',
        image: File('img1.jpg'),
        captions: <String, CaptionEntry>{
          'default': CaptionEntry(text: fakeCaption().toJsonString()),
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
        mockRepository.generateStructuredCaption(
          any,
          any,
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).thenAnswer((_) async => fakeCaption());

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.missing,
      );

      verify(
        mockRepository.generateStructuredCaption(
          any,
          argThat(equals(withoutCaption.image)),
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).called(1);
      verifyNever(
        mockRepository.generateStructuredCaption(
          any,
          argThat(equals(withCaption.image)),
          onProgress: anyNamed('onProgress'),
        ),
      );
    });

    test('all option skips already-caption-edited images', () async {
      final AppImage edited = AppImage(
        id: '1',
        image: File('img1.jpg'),
        captions: const <String, CaptionEntry>{},
        isCaptionEdited: true,
      );
      final AppImage fresh = AppImage(
        id: '2',
        image: File('img2.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      seed(
        ImageListState(images: <AppImage>[edited, fresh], folderPath: '/tmp'),
      );
      when(
        mockRepository.generateStructuredCaption(
          any,
          any,
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).thenAnswer((_) async => fakeCaption());

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.all,
      );

      verify(
        mockRepository.generateStructuredCaption(
          any,
          argThat(equals(fresh.image)),
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).called(1);
      verifyNever(
        mockRepository.generateStructuredCaption(
          any,
          argThat(equals(edited.image)),
          onProgress: anyNamed('onProgress'),
        ),
      );
    });

    test('succeeds with zero images', () async {
      seed(const ImageListState(folderPath: '/tmp'));

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.all,
      );

      expect(cubit.state.status, StructuredCaptioningStatus.success);
      expect(cubit.state.totalImages, 0);
      verifyNever(
        mockRepository.generateStructuredCaption(
          any,
          any,
          onProgress: anyNamed('onProgress'),
        ),
      );
    });

    test('reports failure when repository throws', () async {
      final AppImage image = AppImage(
        id: '1',
        image: File('img.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
      when(
        mockRepository.generateStructuredCaption(
          any,
          any,
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).thenThrow(Exception('API down'));

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.all,
      );

      expect(cubit.state.status, StructuredCaptioningStatus.failure);
      expect(cubit.state.error, contains('API down'));
    });

    test('emits progress and reaches success', () async {
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
        mockRepository.generateStructuredCaption(
          any,
          any,
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).thenAnswer((_) async => fakeCaption());

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.all,
      );

      expect(cubit.state.status, StructuredCaptioningStatus.success);
      expect(cubit.state.processedImages, 2);
      expect(cubit.state.totalImages, 2);
      expect(cubit.state.progress, 1.0);
    });

    test(
      'broadcasts the displayed image guidance to every image in a batch run',
      () async {
        // Regression: guidance used to be strict per-path, so only the image it
        // was keyed to received it during Run-All. The displayed image's guidance
        // must now cover every image in the batch.
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
            currentImageId: '1',
            guidanceEnabled: true,
            imageGuidance: <String, String>{image1.image.path: 'NAME IT MIRA'},
          ),
        );
        // Displayed image (image1) carries guidance; image2 has none of its own.
        when(
          mockRepository.generateStructuredCaption(
            any,
            any,
            onProgress: anyNamed('onProgress'),
            overrides: anyNamed('overrides'),
            debugMode: anyNamed('debugMode'),
          ),
        ).thenAnswer((_) async => fakeCaption());

        await cubit.runStructuredCaptioner(
          llm: llmConfig(),
          option: CaptionOptions.all,
        );

        // Both images receive image1's broadcast guidance.
        verify(
          mockRepository.generateStructuredCaption(
            any,
            argThat(equals(image1.image)),
            onProgress: anyNamed('onProgress'),
            guidance: 'NAME IT MIRA',
          ),
        ).called(1);
        verify(
          mockRepository.generateStructuredCaption(
            any,
            argThat(equals(image2.image)),
            onProgress: anyNamed('onProgress'),
            guidance: 'NAME IT MIRA',
          ),
        ).called(1);
      },
    );

    test('cancelStructuredCaptioning sets isCancelling', () {
      cubit.cancelStructuredCaptioning();
      expect(cubit.state.isCancelling, true);
    });

    test('clearErrors resets status to initial', () async {
      seed(const ImageListState(folderPath: '/tmp'));

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.current,
      );
      expect(cubit.state.status, StructuredCaptioningStatus.failure);

      cubit.clearErrors();
      expect(cubit.state.status, StructuredCaptioningStatus.initial);
    });

    test('maps onProgress step labels to enum values', () async {
      final AppImage image = AppImage(
        id: '1',
        image: File('img.jpg'),
        captions: const <String, CaptionEntry>{},
      );
      void Function(String)? capturedProgress;

      seed(ImageListState(images: <AppImage>[image], folderPath: '/tmp'));
      when(
        mockRepository.generateStructuredCaption(
          any,
          any,
          onProgress: anyNamed('onProgress'),
          overrides: anyNamed('overrides'),
          debugMode: anyNamed('debugMode'),
        ),
      ).thenAnswer((Invocation inv) {
        capturedProgress =
            inv.namedArguments[#onProgress] as void Function(String);
        return Future<IdeogramCaption>.value(fakeCaption());
      });

      await cubit.runStructuredCaptioner(
        llm: llmConfig(),
        option: CaptionOptions.all,
      );

      expect(capturedProgress, isNotNull);
      final void Function(String) onProgress = capturedProgress!;
      onProgress('Extracting color palette...');
      expect(cubit.state.currentStep, StructuredCaptionStep.extractingPalette);
      onProgress('Running VLM analysis...');
      expect(cubit.state.currentStep, StructuredCaptionStep.vlmAnalysis);
      onProgress('Running SAM detection...');
      expect(cubit.state.currentStep, StructuredCaptionStep.samDetection);
      onProgress('Extracting element palettes');
      expect(cubit.state.currentStep, StructuredCaptionStep.elementPalettes);
      onProgress('Building caption...');
      expect(cubit.state.currentStep, StructuredCaptionStep.buildingCaption);
      onProgress('unknown step');
      expect(cubit.state.currentStep, StructuredCaptionStep.idle);
    });

    test(
      'runStructuredCaptioner scoped captions only filtered images',
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

        seed(
          ImageListState(
            images: <AppImage>[image1, image2],
            folderPath: '/tmp',
          ),
        );
        filterEngine.filtered = <AppImage>[image1];

        when(
          mockRepository.generateStructuredCaption(
            any,
            any,
            onProgress: anyNamed('onProgress'),
            overrides: anyNamed('overrides'),
            debugMode: anyNamed('debugMode'),
          ),
        ).thenAnswer((_) async => fakeCaption());

        await cubit.runStructuredCaptioner(
          llm: llmConfig(),
          option: CaptionOptions.all,
          scopeToFiltered: true,
        );

        verify(
          mockRepository.generateStructuredCaption(
            any,
            argThat(equals(image1.image)),
            onProgress: anyNamed('onProgress'),
            overrides: anyNamed('overrides'),
            debugMode: anyNamed('debugMode'),
          ),
        ).called(1);
        verifyNever(
          mockRepository.generateStructuredCaption(
            any,
            argThat(equals(image2.image)),
            onProgress: anyNamed('onProgress'),
            overrides: anyNamed('overrides'),
            debugMode: anyNamed('debugMode'),
          ),
        );
      },
    );

    test(
      'runStructuredCaptioner scoped + all re-captions edited images',
      () async {
        final AppImage editedImage = AppImage(
          id: '1',
          image: File('img1.jpg'),
          captions: const <String, CaptionEntry>{},
          isCaptionEdited: true,
        );

        seed(
          ImageListState(images: <AppImage>[editedImage], folderPath: '/tmp'),
        );
        filterEngine.filtered = <AppImage>[editedImage];

        when(
          mockRepository.generateStructuredCaption(
            any,
            any,
            onProgress: anyNamed('onProgress'),
            overrides: anyNamed('overrides'),
            debugMode: anyNamed('debugMode'),
          ),
        ).thenAnswer((_) async => fakeCaption());

        await cubit.runStructuredCaptioner(
          llm: llmConfig(),
          option: CaptionOptions.all,
          scopeToFiltered: true,
        );

        verify(
          mockRepository.generateStructuredCaption(
            any,
            argThat(equals(editedImage.image)),
            onProgress: anyNamed('onProgress'),
            overrides: anyNamed('overrides'),
            debugMode: anyNamed('debugMode'),
          ),
        ).called(1);
      },
    );
  });
}

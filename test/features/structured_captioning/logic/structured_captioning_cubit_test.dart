import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_options.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/logic/structured_captioning_cubit.dart';

import 'structured_captioning_cubit_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit, StructuredCaptionRepository])
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
    late MockImageListCubit mockImageListCubit;
    late MockStructuredCaptionRepository mockRepository;

    setUp(() {
      mockImageListCubit = MockImageListCubit();
      mockRepository = MockStructuredCaptionRepository();
      cubit = StructuredCaptioningCubit(
        mockImageListCubit,
        repository: mockRepository,
      );
    });

    tearDown(() => cubit.close());

    test('initial state is initial', () {
      expect(cubit.state.status, StructuredCaptioningStatus.initial);
      expect(cubit.state.progress, 0.0);
      expect(cubit.state.isCancelling, false);
      expect(cubit.state.error, isNull);
    });

    test('fails when current image selected but none displayed', () async {
      when(
        mockImageListCubit.state,
      ).thenReturn(const ImageListState(folderPath: '/tmp'));
      when(mockImageListCubit.currentDisplayedImage).thenReturn(null);

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

      when(mockImageListCubit.state).thenReturn(
        ImageListState(images: <AppImage>[image1, image2], folderPath: '/tmp'),
      );
      when(mockImageListCubit.currentDisplayedImage).thenReturn(image2);
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
      final AppImage withCaption = AppImage(
        id: '1',
        image: File('img1.jpg'),
        captions: const <String, CaptionEntry>{
          'default': CaptionEntry(text: 'has caption'),
        },
      );
      final AppImage withoutCaption = AppImage(
        id: '2',
        image: File('img2.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      when(mockImageListCubit.state).thenReturn(
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

      when(mockImageListCubit.state).thenReturn(
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
      when(
        mockImageListCubit.state,
      ).thenReturn(const ImageListState(folderPath: '/tmp'));

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

      when(mockImageListCubit.state).thenReturn(
        ImageListState(images: <AppImage>[image], folderPath: '/tmp'),
      );
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

      when(mockImageListCubit.state).thenReturn(
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

    test('cancelStructuredCaptioning sets isCancelling', () {
      cubit.cancelStructuredCaptioning();
      expect(cubit.state.isCancelling, true);
    });

    test('clearErrors resets status to initial', () async {
      when(
        mockImageListCubit.state,
      ).thenReturn(const ImageListState(folderPath: '/tmp'));
      when(mockImageListCubit.currentDisplayedImage).thenReturn(null);

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

      when(mockImageListCubit.state).thenReturn(
        ImageListState(images: <AppImage>[image], folderPath: '/tmp'),
      );
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
  });
}

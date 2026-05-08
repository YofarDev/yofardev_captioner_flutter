import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_options.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/captioning_repository.dart';
import 'package:yofardev_captioner/features/captioning/logic/captioning_cubit.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';

import 'captioning_cubit_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit, CaptioningRepository])
void main() {
  group('CaptioningCubit', () {
    late CaptioningCubit captioningCubit;
    late MockImageListCubit mockImageListCubit;
    late MockCaptioningRepository mockCaptioningRepository;

    setUp(() {
      mockImageListCubit = MockImageListCubit();
      mockCaptioningRepository = MockCaptioningRepository();
      captioningCubit = CaptioningCubit(
        mockImageListCubit,
        captioningRepository: mockCaptioningRepository,
      );
    });

    tearDown(() {
      captioningCubit.close();
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

        when(
          mockImageListCubit.state,
        ).thenReturn(ImageListState(images: images, folderPath: '/tmp'));

        when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer(
          (Invocation invocation) async =>
              invocation.positionalArguments[1] as AppImage,
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
          ),
        ).called(1);

        async.elapse(const Duration(milliseconds: 500));
        verifyNever(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image2,
            'Test Prompt',
          ),
        );

        async.elapse(const Duration(milliseconds: 501));
        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image2,
            'Test Prompt',
          ),
        ).called(1);
      });
    });

    test('runCaptioner succeeds with zero images', () async {
      when(
        mockImageListCubit.state,
      ).thenReturn(const ImageListState(folderPath: '/tmp'));

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
      verifyNever(mockCaptioningRepository.captionImage(any, any, any));
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

      when(mockImageListCubit.state).thenReturn(
        ImageListState(
          images: <AppImage>[image1, image2],
          folderPath: '/tmp',
          currentImageId: '2',
        ),
      );
      when(mockImageListCubit.currentDisplayedImage).thenReturn(image2);
      when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer(
        (Invocation invocation) async =>
            invocation.positionalArguments[1] as AppImage,
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
        mockCaptioningRepository.captionImage(llmConfig, image2, 'Prompt'),
      ).called(1);
      verifyNever(
        mockCaptioningRepository.captionImage(llmConfig, image1, 'Prompt'),
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

      when(mockImageListCubit.state).thenReturn(
        ImageListState(
          images: <AppImage>[withCaption, withoutCaption],
          folderPath: '/tmp',
        ),
      );
      when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer(
        (Invocation invocation) async =>
            invocation.positionalArguments[1] as AppImage,
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
        ),
      ).called(1);
      verifyNever(
        mockCaptioningRepository.captionImage(llmConfig, withCaption, 'Prompt'),
      );
    });

    test('runCaptioner handles errors and reports failure', () async {
      final AppImage image = AppImage(
        id: '1',
        image: File('img.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      when(mockImageListCubit.state).thenReturn(
        ImageListState(images: <AppImage>[image], folderPath: '/tmp'),
      );
      when(
        mockCaptioningRepository.captionImage(any, any, any),
      ).thenThrow(Exception('API error'));

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
      expect(captioningCubit.state.error, contains('API error'));
      expect(captioningCubit.state.processedImages, 0);
    });

    test('cancelCaptioning sets isCancelling', () {
      captioningCubit.cancelCaptioning();

      expect(captioningCubit.state.isCancelling, true);
    });

    test('clearErrors resets status to initial', () async {
      final AppImage image = AppImage(
        id: '1',
        image: File('img.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      when(mockImageListCubit.state).thenReturn(
        ImageListState(images: <AppImage>[image], folderPath: '/tmp'),
      );
      when(
        mockCaptioningRepository.captionImage(any, any, any),
      ).thenThrow(Exception('fail'));

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

      when(mockImageListCubit.state).thenReturn(
        ImageListState(images: <AppImage>[image1, image2], folderPath: '/tmp'),
      );
      when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer(
        (Invocation invocation) async =>
            invocation.positionalArguments[1] as AppImage,
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

        when(mockImageListCubit.state).thenReturn(
          ImageListState(
            images: <AppImage>[edited, notEdited],
            folderPath: '/tmp',
          ),
        );
        when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer(
          (Invocation invocation) async =>
              invocation.positionalArguments[1] as AppImage,
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
          mockCaptioningRepository.captionImage(llmConfig, notEdited, 'Prompt'),
        ).called(1);
        verifyNever(
          mockCaptioningRepository.captionImage(llmConfig, edited, 'Prompt'),
        );
      },
    );
  });
}

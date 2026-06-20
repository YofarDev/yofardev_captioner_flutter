import 'dart:async';
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
        when(mockImageListCubit.state).thenAnswer(
          (_) => ImageListState(
            images: <AppImage>[image1, image2],
            folderPath: '/tmp',
            activeCategory: activeCategory,
          ),
        );

        final List<String> categoriesPassed = <String>[];
        final Completer<AppImage> call1 = Completer<AppImage>();
        final Completer<AppImage> call2 = Completer<AppImage>();
        int callIndex = 0;
        when(
          mockCaptioningRepository.captionImage(
            any,
            any,
            any,
            category: anyNamed('category'),
          ),
        ).thenAnswer((Invocation inv) {
          categoriesPassed.add(
            inv.namedArguments[const Symbol('category')] as String,
          );
          final Completer<AppImage> c = callIndex == 0 ? call1 : call2;
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

        call1.complete(
          image1.copyWith(
            captions: const <String, CaptionEntry>{
              'caption1': CaptionEntry(text: 'c1'),
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);

        // Second image must STILL use the start category (caption1).
        expect(categoriesPassed, <String>['caption1', 'caption1']);

        call2.complete(
          image2.copyWith(
            captions: const <String, CaptionEntry>{
              'caption1': CaptionEntry(text: 'c2'),
            },
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

        when(mockImageListCubit.state).thenReturn(
          ImageListState(images: <AppImage>[image], folderPath: '/tmp'),
        );
        when(mockImageListCubit.currentDisplayedImage).thenReturn(image);
        when(mockCaptioningRepository.rewriteCaption(any, any, any)).thenAnswer(
          (Invocation inv) async {
            final AppImage img = inv.positionalArguments[1] as AppImage;
            return img.copyWith(
              captions: const <String, CaptionEntry>{
                'default': CaptionEntry(
                  text: 'A young woman stands.',
                  isEdited: true,
                ),
              },
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

        final AppImage passed =
            verify(
                  mockImageListCubit.updateImage(
                    image: captureAnyNamed('image'),
                  ),
                ).captured.single
                as AppImage;
        expect(passed.captions['default']?.text, 'A young woman stands.');
        expect(passed.captions['default']?.isEdited, true);
      });

      test('throws when no current image is selected', () async {
        when(
          mockImageListCubit.state,
        ).thenReturn(const ImageListState(folderPath: '/tmp'));
        when(mockImageListCubit.currentDisplayedImage).thenReturn(null);

        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        await expectLater(
          captioningCubit.rewriteCaption(llm: llmConfig, instructions: 'x'),
          throwsA(isA<Exception>()),
        );
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

          when(mockImageListCubit.state).thenReturn(
            ImageListState(images: <AppImage>[image], folderPath: '/tmp'),
          );
          when(mockImageListCubit.currentDisplayedImage).thenReturn(image);
          when(
            mockCaptioningRepository.rewriteCaption(any, any, any),
          ).thenThrow(Exception('API error'));

          final LlmConfig llmConfig = LlmConfig(
            id: '1',
            name: 'Test',
            model: 'gpt-4',
            providerType: LlmProviderType.remote,
          );

          await expectLater(
            captioningCubit.rewriteCaption(
              llm: llmConfig,
              instructions: 'make it better',
            ),
            throwsA(isA<Exception>()),
          );
          verifyNever(mockImageListCubit.updateImage(image: anyNamed('image')));
        },
      );
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

          when(
            mockImageListCubit.state,
          ).thenReturn(ImageListState(images: allImages, folderPath: '/tmp'));
          // Stub the filteredImages getter: only image1 is in the filtered set.
          when(
            mockImageListCubit.filteredImages,
          ).thenReturn(<AppImage>[image1]);

          when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer(
            (Invocation invocation) async =>
                invocation.positionalArguments[1] as AppImage,
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
            ),
          ).called(1);
          verifyNever(
            mockCaptioningRepository.captionImage(llmConfig, image2, any),
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

        when(mockImageListCubit.state).thenReturn(
          ImageListState(images: <AppImage>[editedImage], folderPath: '/tmp'),
        );
        when(
          mockImageListCubit.filteredImages,
        ).thenReturn(<AppImage>[editedImage]);

        when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer(
          (Invocation invocation) async =>
              invocation.positionalArguments[1] as AppImage,
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

        when(mockImageListCubit.state).thenReturn(
          ImageListState(images: <AppImage>[editedImage], folderPath: '/tmp'),
        );

        when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer(
          (Invocation invocation) async =>
              invocation.positionalArguments[1] as AppImage,
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
          mockCaptioningRepository.captionImage(llmConfig, editedImage, any),
        );
      });
    });
  });
}

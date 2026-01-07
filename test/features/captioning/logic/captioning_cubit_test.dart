import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/logic/captioning/captioning_cubit.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/models/caption_options.dart';
import 'package:yofardev_captioner/models/llm_config.dart';
import 'package:yofardev_captioner/models/llm_provider_type.dart';
import 'package:yofardev_captioner/repositories/captioning_repository.dart';

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

    test('runCaptioner applies delay between requests', () {
      fakeAsync((FakeAsync async) {
        // Setup
        final AppImage image1 = AppImage(
          id: '1',
          image: File('path/to/img1.jpg'),
          caption: '',
        );
        final AppImage image2 = AppImage(
          id: '2',
          image: File('path/to/img2.jpg'),
          caption: '',
        );
        final List<AppImage> images = <AppImage>[image1, image2];
        final LlmConfig llmConfig = LlmConfig(
          id: '1',
          name: 'Test LLM',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
          apiKey: 'key',
          delay: 1000, // 1 second delay
        );

        when(
          mockImageListCubit.state,
        ).thenReturn(ImageListState(images: images, folderPath: '/tmp'));

        when(mockCaptioningRepository.captionImage(any, any, any)).thenAnswer((
          Invocation invocation,
        ) async {
          return invocation.positionalArguments[1] as AppImage;
        });

        // Act
        captioningCubit.runCaptioner(
          llm: llmConfig,
          prompt: 'Test Prompt',
          option: CaptionOptions.all,
        );

        // Assert
        // Initial state should be in progress
        expect(captioningCubit.state.status, CaptioningStatus.inProgress);

        // Fast forward 500ms (less than delay) - First request should have happened immediately (or very soon) if we implement delay *after* request.
        // If we delay *between* requests, the first one goes, then delay, then second.

        // Let's assume implementation: request 1 -> delay -> request 2.

        // At T=0, Request 1 starts.
        async.flushMicrotasks();
        verify(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image1,
            'Test Prompt',
          ),
        ).called(1);

        // Now it should be waiting for 1000ms.
        // If I advance 500ms, second request should NOT happen yet.
        async.elapse(const Duration(milliseconds: 500));
        verifyNever(
          mockCaptioningRepository.captionImage(
            llmConfig,
            image2,
            'Test Prompt',
          ),
        );

        // Advance another 500ms (Total 1000ms). Second request should happen now.
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
  });
}

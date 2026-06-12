import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/caption_repository.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/captioning_repository.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';

import 'captioning_repository_test.mocks.dart';

@GenerateMocks(<Type>[CaptionRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    locator.registerLazySingleton(() => Logger('App'));
  });

  group('CaptioningRepository', () {
    late CaptioningRepository repository;
    late MockCaptionRepository mockCaptionRepository;

    setUp(() {
      mockCaptionRepository = MockCaptionRepository();
      repository = CaptioningRepository(
        captionRepository: mockCaptionRepository,
      );
    });

    final LlmConfig testConfig = LlmConfig(
      name: 'test-model',
      model: 'gpt-4',
      apiKey: 'key',
      providerType: LlmProviderType.remote,
    );

    final AppImage testImage = AppImage(
      id: 'img-1',
      image: File('/test/image.jpg'),
      captions: const <String, CaptionEntry>{},
    );

    test(
      'captionImage returns image with updated caption in default category',
      () async {
        when(
          mockCaptionRepository.getCaption(any, any, any),
        ).thenAnswer((_) async => 'a beautiful landscape');

        final AppImage result = await repository.captionImage(
          testConfig,
          testImage,
          'describe',
        );

        expect(result.captions['default']?.text, 'a beautiful landscape');
        expect(result.captions['default']?.model, 'test-model');
        expect(result.captions['default']?.timestamp, isNotNull);
        expect(result.lastModified, isNotNull);
      },
    );

    test('captionImage uses custom category when provided', () async {
      when(
        mockCaptionRepository.getCaption(any, any, any),
      ).thenAnswer((_) async => 'detailed caption');

      final AppImage result = await repository.captionImage(
        testConfig,
        testImage,
        'describe',
        category: 'detailed',
      );

      expect(result.captions['detailed']?.text, 'detailed caption');
      expect(result.captions['detailed']?.model, 'test-model');
    });

    test('captionImage preserves existing captions', () async {
      final AppImage imageWithCaption = AppImage(
        id: 'img-1',
        image: File('/test/image.jpg'),
        captions: const <String, CaptionEntry>{
          'default': CaptionEntry(text: 'old caption'),
        },
      );

      when(
        mockCaptionRepository.getCaption(any, any, any),
      ).thenAnswer((_) async => 'new caption');

      final AppImage result = await repository.captionImage(
        testConfig,
        imageWithCaption,
        'describe',
        category: 'detailed',
      );

      // Original preserved
      expect(result.captions['default']?.text, 'old caption');
      // New category added
      expect(result.captions['detailed']?.text, 'new caption');
    });

    test(
      'captionImage delegates to CaptionRepository with correct args',
      () async {
        when(
          mockCaptionRepository.getCaption(any, any, any),
        ).thenAnswer((_) async => 'caption');

        await repository.captionImage(testConfig, testImage, 'my prompt');

        verify(
          mockCaptionRepository.getCaption(testConfig, testImage, 'my prompt'),
        ).called(1);
      },
    );

    test('captionImage propagates exceptions from repository', () {
      when(
        mockCaptionRepository.getCaption(any, any, any),
      ).thenThrow(Exception('API failure'));

      expect(
        () => repository.captionImage(testConfig, testImage, 'prompt'),
        throwsException,
      );
    });
  });
}

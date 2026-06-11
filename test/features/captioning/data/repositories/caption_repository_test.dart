import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/caption_repository.dart';
import 'package:yofardev_captioner/features/captioning/data/services/caption_service.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';

import 'caption_repository_test.mocks.dart';

@GenerateMocks(<Type>[CaptionService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    locator.registerLazySingleton(() => Logger('App'));
  });

  group('CaptionRepository', () {
    late CaptionRepository repository;
    late MockCaptionService mockCaptionService;

    setUp(() {
      mockCaptionService = MockCaptionService();
      repository = CaptionRepository(captionService: mockCaptionService);
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
      'getCaption delegates to CaptionService with correct arguments',
      () async {
        when(
          mockCaptionService.getCaption(any, any, any),
        ).thenAnswer((_) async => 'a caption');

        final String result = await repository.getCaption(
          testConfig,
          testImage,
          'describe this image',
        );

        expect(result, 'a caption');
        verify(
          mockCaptionService.getCaption(
            testConfig,
            testImage.image,
            'describe this image',
          ),
        ).called(1);
      },
    );

    test('getCaption propagates exceptions from service', () async {
      when(
        mockCaptionService.getCaption(any, any, any),
      ).thenThrow(Exception('API error'));

      expect(
        () => repository.getCaption(testConfig, testImage, 'prompt'),
        throwsException,
      );
    });

    test('getCaption passes File object not AppImage to service', () async {
      when(
        mockCaptionService.getCaption(any, any, any),
      ).thenAnswer((_) async => 'caption');

      await repository.getCaption(testConfig, testImage, 'prompt');

      final List<Object?> captured = verify(
        mockCaptionService.getCaption(any, captureAny, any),
      ).captured;
      expect(captured.first, isA<File>());
    });
  });
}

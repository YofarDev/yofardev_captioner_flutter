import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/caption_repository.dart';
import 'package:yofardev_captioner/features/captioning/data/services/caption_service.dart';

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

        final Either<Failure, String> result = await repository.getCaption(
          testConfig,
          testImage,
          'describe this image',
        );

        expect(result.getRight().toNullable(), 'a caption');
        verify(
          mockCaptionService.getCaption(
            testConfig,
            testImage.image,
            'describe this image',
          ),
        ).called(1);
      },
    );

    test(
      'getCaption maps unknown service exceptions to Failure.unexpected',
      () async {
        when(
          mockCaptionService.getCaption(any, any, any),
        ).thenThrow(Exception('API error'));

        final Either<Failure, String> result = await repository.getCaption(
          testConfig,
          testImage,
          'prompt',
        );

        expect(result.getLeft().toNullable(), isA<FailureUnexpected>());
      },
    );

    test('ApiException with 401 maps to Failure.unauthorized', () async {
      when(
        mockCaptionService.getCaption(any, any, any),
      ).thenThrow(ApiException('Failed to load caption (401): bad key'));

      final Either<Failure, String> result = await repository.getCaption(
        testConfig,
        testImage,
        'prompt',
      );

      final Failure? failure = result.getLeft().toNullable();
      expect(failure, isA<FailureUnauthorized>());
    });

    test(
      'ApiException with statusCode 401 but no code in message maps to unauthorized',
      () async {
        when(
          mockCaptionService.getCaption(any, any, any),
        ).thenThrow(ApiException('Invalid credentials', statusCode: 401));

        final Either<Failure, String> result = await repository.getCaption(
          testConfig,
          testImage,
          'prompt',
        );

        expect(result.getLeft().toNullable(), isA<FailureUnauthorized>());
      },
    );

    test(
      'ApiException with other status maps to Failure.serverError',
      () async {
        when(
          mockCaptionService.getCaption(any, any, any),
        ).thenThrow(ApiException('Failed to load caption (500): boom'));

        final Either<Failure, String> result = await repository.getCaption(
          testConfig,
          testImage,
          'prompt',
        );

        expect(result.getLeft().toNullable(), isA<FailureServer>());
      },
    );

    test('TimeoutException maps to Failure.network', () async {
      when(
        mockCaptionService.getCaption(any, any, any),
      ).thenThrow(TimeoutException('timed out'));

      final Either<Failure, String> result = await repository.getCaption(
        testConfig,
        testImage,
        'prompt',
      );

      expect(result.getLeft().toNullable(), isA<FailureNetwork>());
    });

    test('TypeError maps to Failure.unexpected (malformed DTO)', () async {
      when(
        mockCaptionService.getCaption(any, any, any),
      ).thenThrow(StateError('malformed DTO'));

      final Either<Failure, String> result = await repository.getCaption(
        testConfig,
        testImage,
        'prompt',
      );

      expect(result.getLeft().toNullable(), isA<FailureUnexpected>());
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

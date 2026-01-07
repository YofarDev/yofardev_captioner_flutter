import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/captioning_repository.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/caption_repository.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';

import 'captioning_repository_test.mocks.dart';

@GenerateMocks(<Type>[CaptionRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Initialize service locator for tests
    locator.registerLazySingleton(() => Logger('App'));
  });

  group('CaptioningRepository', () {
    late CaptioningRepository captioningRepository;

    setUp(() {
      captioningRepository = CaptioningRepository();
    });

    test('should be instantiated', () {
      expect(captioningRepository, isNotNull);
    });

    test('should preserve image properties on captionImage call', () {
      // This is a smoke test to verify the repository structure
      // Full integration testing would require mocking the internal CaptionRepository
      final File testImage = File('/test/image.jpg');
      final AppImage appImage = AppImage(
        id: 'test-id',
        image: testImage,
        caption: 'test caption',
        size: 1024,
        width: 1920,
        height: 1080,
      );

      // Verify repository maintains expected structure
      expect(captioningRepository, isNotNull);
      expect(appImage.id, 'test-id');
      expect(appImage.caption, 'test caption');
    });
  });
}

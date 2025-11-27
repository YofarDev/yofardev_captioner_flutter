import 'dart:async';

import '../models/app_image.dart';
import '../models/llm_config.dart';
import '../repositories/caption_repository.dart';

class CaptioningRepository {
  final CaptionRepository _captionRepository = CaptionRepository();
  Future<AppImage> captionImage(
    LlmConfig config,
    AppImage image,
    String prompt,
  ) async {
    final String caption = await _captionRepository.getCaption(
      config,
      image,
      prompt,
    );
    final DateTime timestamp = DateTime.now();
    return image.copyWith(
      caption: caption,
      captionModel: config.name,
      captionTimestamp: timestamp,
      isCaptionEdited:
          true, // A newly generated caption is not "edited" by the user
    );
  }
}

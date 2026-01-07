import 'dart:async';

import '../../../image_list/data/models/app_image.dart';
import '../../../llm_config/data/models/llm_config.dart';
import './caption_repository.dart';

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

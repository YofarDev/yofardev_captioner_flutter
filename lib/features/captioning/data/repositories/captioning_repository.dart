import 'dart:async';

import '../../../image_list/data/models/app_image.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../models/caption_entry.dart';
import './caption_repository.dart';

class CaptioningRepository {
  final CaptionRepository _captionRepository = CaptionRepository();
  Future<AppImage> captionImage(
    LlmConfig config,
    AppImage image,
    String prompt, {
    String category = 'default',
  }) async {
    final String caption = await _captionRepository.getCaption(
      config,
      image,
      prompt,
    );
    final DateTime timestamp = DateTime.now();
    return image.copyWith(
      captions: <String, CaptionEntry>{
        ...image.captions,
        category: CaptionEntry(
          text: caption,
          model: config.name,
          timestamp: timestamp,
          isEdited: false,
        ),
      },
      lastModified: timestamp,
    );
  }
}

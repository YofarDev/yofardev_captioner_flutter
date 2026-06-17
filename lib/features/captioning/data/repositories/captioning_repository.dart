import '../../../image_list/data/models/app_image.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../models/caption_entry.dart';
import './caption_repository.dart';

class CaptioningRepository {
  final CaptionRepository _captionRepository;
  CaptioningRepository({CaptionRepository? captionRepository})
    : _captionRepository = captionRepository ?? CaptionRepository();

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
        ),
      },
      lastModified: timestamp,
    );
  }

  /// Rewrites the existing caption for the given category (text-only). The
  /// resulting caption is marked as edited so it is skipped by future "All
  /// images" vision batches, matching how manual edits are treated.
  Future<AppImage> rewriteCaption(
    LlmConfig config,
    AppImage image,
    String instructions, {
    String category = 'default',
  }) async {
    final String currentCaption = image.captions[category]?.text ?? '';
    final String rewritten = await _captionRepository.rewriteCaption(
      config,
      currentCaption,
      instructions,
    );
    final DateTime timestamp = DateTime.now();
    return image.copyWith(
      captions: <String, CaptionEntry>{
        ...image.captions,
        category: CaptionEntry(
          text: rewritten,
          model: config.name,
          timestamp: timestamp,
          isEdited: true,
        ),
      },
      lastModified: timestamp,
    );
  }
}

import '../../../image_list/data/models/app_image.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../services/caption_service.dart';

class CaptionRepository {
  final CaptionService _captionService;
  CaptionRepository({CaptionService? captionService})
    : _captionService = captionService ?? CaptionService();

  Future<String> getCaption(LlmConfig config, AppImage image, String prompt) {
    return _captionService.getCaption(config, image.image, prompt);
  }

  /// Rewrites an existing caption (text-only) using the LLM.
  Future<String> rewriteCaption(
    LlmConfig config,
    String currentCaption,
    String instructions,
  ) {
    return _captionService.rewriteCaption(config, currentCaption, instructions);
  }
}

import '../../../../core/models/app_image.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/utils/cancel_token.dart';
import '../services/caption_service.dart';

class CaptionRepository {
  final CaptionService _captionService;
  CaptionRepository({CaptionService? captionService})
    : _captionService = captionService ?? CaptionService();

  Future<String> getCaption(
    LlmConfig config,
    AppImage image,
    String prompt, {
    CancelToken? cancelToken,
  }) {
    return _captionService.getCaption(
      config,
      image.image,
      prompt,
      cancelToken: cancelToken,
    );
  }

  /// Rewrites an existing caption (text-only) using the LLM.
  Future<String> rewriteCaption(
    LlmConfig config,
    String currentCaption,
    String instructions,
  ) {
    return _captionService.rewriteCaption(config, currentCaption, instructions);
  }

  /// Generic text-only transform driven entirely by [userPrompt]
  /// (e.g. JSON → natural language).
  Future<String> transformCaption(
    LlmConfig config,
    String sourceText,
    String userPrompt,
  ) {
    return _captionService.transformCaption(config, sourceText, userPrompt);
  }
}

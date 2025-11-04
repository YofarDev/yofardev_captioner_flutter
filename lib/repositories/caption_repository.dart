import '../models/app_image.dart';
import '../models/llm_config.dart';
import '../services/caption_service.dart';

class CaptionRepository {
  final CaptionService _captionService = CaptionService();

  Future<String> getCaption(
    LlmConfig config,
    AppImage image,
    String prompt,
  )  {
    return _captionService.getCaption(config, image.image, prompt);
  }
}

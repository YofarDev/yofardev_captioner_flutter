import '../../../../core/models/app_image.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/utils/cancel_token.dart';

/// Domain-facing port for caption generation, rewriting, and
/// category-to-category transforms. Implemented by the data-layer
/// `CaptioningRepository`.
abstract class ICaptioningRepository {
  /// Generates a caption for [image] in the given [category].
  Future<AppImage> captionImage(
    LlmConfig config,
    AppImage image,
    String prompt, {
    String category = 'default',
    CancelToken? cancelToken,
  });

  /// Rewrites the existing caption for the given category (text-only).
  Future<AppImage> rewriteCaption(
    LlmConfig config,
    AppImage image,
    String instructions, {
    String category = 'default',
    CancelToken? cancelToken,
  });

  /// Transforms the caption of [sourceCategory] into [targetCategory].
  Future<AppImage> transformCaption(
    LlmConfig config,
    AppImage image,
    String sourceCategory,
    String targetCategory,
    String userPrompt,
  );
}

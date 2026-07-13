import 'package:flutter/services.dart';

/// Loads bundled prompt assets for structured captioning.
class StructuredPromptLoader {
  static const String _visionAnalysisPath =
      'assets/prompts/vision_analysis.txt';
  static const String _elementRecaptionPath =
      'assets/prompts/element_recaption.txt';
  static const String _styleRecaptionPath =
      'assets/prompts/style_recaption.txt';
  // ponytail: vision prompts use double-brace tokens ({{bbox_order}},
  // {{aspect_ratio}}) substituted by the repository; element_enrich uses
  // single-brace {name}/{type} like element_recaption's {existingJson}.
  static const String _visionEnumeratePath =
      'assets/prompts/vision_enumerate.txt';
  static const String _elementEnrichPath =
      'assets/prompts/element_enrich.txt';

  /// Loads the VLM vision analysis prompt from bundled assets.
  Future<String> loadVisionAnalysisPrompt() =>
      rootBundle.loadString(_visionAnalysisPath);

  /// Loads the single-element recaption prompt from bundled assets.
  Future<String> loadElementRecaptionPrompt() =>
      rootBundle.loadString(_elementRecaptionPath);

  /// Loads the whole-style recaption prompt from bundled assets.
  Future<String> loadStyleRecaptionPrompt() =>
      rootBundle.loadString(_styleRecaptionPath);

  /// Loads the multi-stage vision enumeration prompt from bundled assets.
  Future<String> loadVisionEnumeratePrompt() =>
      rootBundle.loadString(_visionEnumeratePath);

  /// Loads the single-element enrichment prompt from bundled assets.
  Future<String> loadElementEnrichPrompt() =>
      rootBundle.loadString(_elementEnrichPath);
}

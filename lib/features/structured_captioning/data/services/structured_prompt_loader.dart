import 'package:flutter/services.dart';

/// Loads bundled prompt assets for structured captioning.
class StructuredPromptLoader {
  static const String _visionAnalysisPath =
      'assets/prompts/vision_analysis.txt';
  static const String _elementRecaptionPath =
      'assets/prompts/element_recaption.txt';
  static const String _styleRecaptionPath =
      'assets/prompts/style_recaption.txt';

  /// Loads the VLM vision analysis prompt from bundled assets.
  Future<String> loadVisionAnalysisPrompt() =>
      rootBundle.loadString(_visionAnalysisPath);

  /// Loads the single-element recaption prompt from bundled assets.
  Future<String> loadElementRecaptionPrompt() =>
      rootBundle.loadString(_elementRecaptionPath);

  /// Loads the whole-style recaption prompt from bundled assets.
  Future<String> loadStyleRecaptionPrompt() =>
      rootBundle.loadString(_styleRecaptionPath);
}

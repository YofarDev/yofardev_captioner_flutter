import 'package:flutter/services.dart';

/// Loads bundled prompt assets for structured captioning.
class StructuredPromptLoader {
  static const String _visionAnalysisPath =
      'assets/prompts/vision_analysis.txt';

  /// Loads the VLM vision analysis prompt from bundled assets.
  Future<String> loadVisionAnalysisPrompt() =>
      rootBundle.loadString(_visionAnalysisPath);
}

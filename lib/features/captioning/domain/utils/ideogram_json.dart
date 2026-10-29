import 'dart:convert';

import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/moss_layout_caption.dart';

/// Result of attempting to parse + normalize a raw structured caption JSON
/// blob (Ideogram or MOSS layout).
///
/// Exactly one of [normalized] / [error] is non-null.
class IdeogramJsonResult {
  const IdeogramJsonResult.success(this.normalized) : error = null;

  const IdeogramJsonResult.failure(this.error) : normalized = null;

  final String? normalized;
  final String? error;

  bool get isSuccess => normalized != null;
}

/// Strictly validates [text] as a structured caption JSON object (Ideogram4
/// or MOSS layout) and returns the normalized compact form, round-tripped
/// through the matching model.
///
/// Requirements for Ideogram JSON:
///   - Must be a JSON object (starts with "{").
///   - Must contain `high_level_description` and `compositional_deconstruction`.
///   - Must round-trip through [IdeogramCaption.fromJson].
///
/// Requirements for MOSS JSON:
///   - Must contain a `summary` object with a `caption` and an `items` array.
///   - Must round-trip through [MossLayoutCaption.fromJson].
IdeogramJsonResult parseStructuredCaptionJson(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const IdeogramJsonResult.failure('Input is empty.');
  }
  if (!trimmed.startsWith('{')) {
    return const IdeogramJsonResult.failure(
      'JSON must be an object starting with "{".',
    );
  }

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(trimmed) as Map<String, dynamic>;
  } on FormatException catch (e) {
    return IdeogramJsonResult.failure('Invalid JSON: ${e.message}');
  } catch (_) {
    return const IdeogramJsonResult.failure('Invalid JSON.');
  }

  final bool isIdeogram =
      data.containsKey('high_level_description') &&
      data.containsKey('compositional_deconstruction');
  final bool isMoss =
      data['summary'] is Map<String, dynamic> && data['items'] is List<dynamic>;

  if (!isIdeogram && !isMoss) {
    return const IdeogramJsonResult.failure(
      'Missing required keys: "high_level_description" and/or '
      '"compositional_deconstruction" (Ideogram), or "summary"/"items" '
      '(MOSS).',
    );
  }

  try {
    if (isIdeogram) {
      final IdeogramCaption caption = IdeogramCaption.fromJson(data);
      return IdeogramJsonResult.success(caption.toJsonString());
    }
    final MossLayoutCaption caption = MossLayoutCaption.fromJson(data);
    return IdeogramJsonResult.success(caption.toJsonString());
  } catch (e) {
    return IdeogramJsonResult.failure('Could not parse structured caption: $e');
  }
}

/// Backward-compatible alias for [parseStructuredCaptionJson].
IdeogramJsonResult parseIdeogramCaptionJson(String text) =>
    parseStructuredCaptionJson(text);

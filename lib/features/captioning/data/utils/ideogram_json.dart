import 'dart:convert';

import '../../../structured_captioning/data/models/ideogram_caption.dart';

/// Result of attempting to parse + normalize a raw Ideogram caption JSON blob.
///
/// Exactly one of [normalized] / [error] is non-null.
class IdeogramJsonResult {
  const IdeogramJsonResult.success(this.normalized) : error = null;

  const IdeogramJsonResult.failure(this.error) : normalized = null;

  final String? normalized;
  final String? error;

  bool get isSuccess => normalized != null;
}

/// Strictly validates [text] as an Ideogram caption JSON object and returns the
/// normalized compact form (round-tripped through [IdeogramCaption]).
///
/// Requirements:
///   - Must be a JSON object (starts with "{").
///   - Must contain `high_level_description` and `compositional_deconstruction`.
///   - Must round-trip through [IdeogramCaption.fromJson].
IdeogramJsonResult parseIdeogramCaptionJson(String text) {
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

  if (!data.containsKey('high_level_description') ||
      !data.containsKey('compositional_deconstruction')) {
    return const IdeogramJsonResult.failure(
      'Missing required keys: "high_level_description" and/or '
      '"compositional_deconstruction".',
    );
  }

  try {
    final IdeogramCaption caption = IdeogramCaption.fromJson(data);
    return IdeogramJsonResult.success(caption.toJsonString());
  } catch (e) {
    return IdeogramJsonResult.failure(
      'Could not parse Ideogram caption: $e',
    );
  }
}

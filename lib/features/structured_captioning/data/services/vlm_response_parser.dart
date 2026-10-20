import 'dart:convert';

import 'package:logging/logging.dart';

import '../../../../core/di/service_locator.dart';
import '../models/vlm_analysis.dart';

/// Pure parsing layer for raw VLM responses: markdown-fence stripping, JSON
/// object extraction, strict parse, and truncated-response recovery.
///
/// Stateless with respect to the pipeline — the repository owns LLM calls
/// (including the model-side JSON repair retry) and delegates the textual
/// interpretation of responses here.
class VlmResponseParser {
  final Logger _logger = locator<Logger>();

  /// Parses the VLM response string into a [VlmAnalysis].
  ///
  /// Strips markdown code fences and handles common JSON formatting issues
  /// (stray preamble, trailing prose). On total failure throws so the caller
  /// can retry with a simplified prompt.
  VlmAnalysis parseVlmResponse(String raw, {bool vlmEmitsXyxy = true}) {
    final String? jsonStr = extractJsonObject(raw);
    if (jsonStr == null) {
      _logger.warning('Failed to parse VLM response: no JSON object found');
      _logger.fine('Raw response was: $raw');
      throw const FormatException(
        'Failed to parse VLM JSON response: no JSON object found',
      );
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(jsonStr) as Map<String, dynamic>;
      return parseAnalysisJson(json, vlmEmitsXyxy: vlmEmitsXyxy);
    } catch (e) {
      _logger.warning('Failed to parse VLM response: $e');
      _logger.fine('Raw response was: $raw');
      throw FormatException('Failed to parse VLM JSON response: $e');
    }
  }

  /// Extracts the JSON object string from a raw VLM response.
  ///
  /// Handles: surrounding whitespace, prose preamble/postamble, and
  /// ```json fenced blocks. Falls back to the outermost `{...}` span when the
  /// fenced/trimmed content still won't parse. Returns null when no object is
  /// found.
  String? extractJsonObject(String raw) {
    final String s = stripMarkdownFences(raw);
    // Fast path: already a clean JSON object.
    final String trimmed = s.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        jsonDecode(trimmed);
        return trimmed;
      } catch (_) {
        // Fall through to span extraction.
      }
    }
    // Fallback: pull the outermost {...} span to tolerate stray prose and
    // nested fences the model may add around the object.
    final int start = s.indexOf('{');
    final int end = s.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    final String candidate = s.substring(start, end + 1);
    // Validate the extracted span before returning it. A truncated response
    // (e.g. from hitting max_tokens) may contain an inner `}` from a
    // completed sub-object but no balanced top-level `}` — returning that
    // fragment makes jsonDecode throw the cryptic "unexpected end of input".
    // Returning null here yields a clearer error upstream.
    try {
      jsonDecode(candidate);
      return candidate;
    } catch (_) {
      return null;
    }
  }

  /// Recovers a usable [VlmAnalysis] from a truncated enumerate response.
  ///
  /// Local MLX cannot run the text-only JSON repair pass, and runaway
  /// repetition can truncate an otherwise useful enumerate response before the
  /// top-level object closes. This fallback parses the complete top-level
  /// header and every complete object literal already emitted inside
  /// `objects`, then lets the normal parser normalize bboxes and fields.
  VlmAnalysis parsePartialVlmResponse(String raw, {bool vlmEmitsXyxy = true}) {
    final String s = stripMarkdownFences(raw);
    final int objectsKey = s.indexOf('"objects"');
    if (objectsKey < 0) {
      throw const FormatException(
        'Failed to recover partial VLM JSON: no objects key found',
      );
    }
    final int arrayStart = s.indexOf('[', objectsKey);
    if (arrayStart < 0) {
      throw const FormatException(
        'Failed to recover partial VLM JSON: no objects array found',
      );
    }

    final Map<String, dynamic> header = _parsePartialHeader(
      s.substring(0, objectsKey),
    );
    final List<Map<String, dynamic>> objects = _parseCompleteObjectLiterals(
      s.substring(arrayStart + 1),
    );
    if (objects.isEmpty) {
      throw const FormatException(
        'Failed to recover partial VLM JSON: no complete objects found',
      );
    }

    return parseAnalysisJson(<String, dynamic>{
      'high_level_description': header['high_level_description'] ?? '',
      'style': header['style'] ?? <String, dynamic>{},
      'background': header['background'] ?? '',
      'objects': objects,
    }, vlmEmitsXyxy: vlmEmitsXyxy);
  }

  Map<String, dynamic> _parsePartialHeader(String prefix) {
    final String headerCandidate =
        '${prefix.replaceFirst(RegExp(r',\s*$'), '')}}';
    try {
      return jsonDecode(headerCandidate) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{
        'high_level_description': _extractJsonStringField(
          prefix,
          'high_level_description',
        ),
        'style': _extractStyleObject(prefix),
        'background': _extractJsonStringField(prefix, 'background'),
      };
    }
  }

  List<Map<String, dynamic>> _parseCompleteObjectLiterals(String arrayTail) {
    final List<Map<String, dynamic>> objects = <Map<String, dynamic>>[];
    int depth = 0;
    int objectStart = -1;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < arrayTail.length; i++) {
      final String ch = arrayTail[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == '\\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{') {
        if (depth == 0) objectStart = i;
        depth++;
      } else if (ch == '}') {
        if (depth == 0) continue;
        depth--;
        if (depth == 0 && objectStart >= 0) {
          final String literal = arrayTail.substring(objectStart, i + 1);
          try {
            objects.add(jsonDecode(literal) as Map<String, dynamic>);
          } catch (_) {
            // Ignore malformed object fragments and keep scanning for later
            // complete objects.
          }
          objectStart = -1;
        }
      } else if (ch == ']' && depth == 0) {
        break;
      }
    }
    return objects;
  }

  String _extractJsonStringField(String source, String field) {
    final RegExp regex = RegExp(
      '"$field"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"',
      dotAll: true,
    );
    final RegExpMatch? match = regex.firstMatch(source);
    if (match == null) return '';
    try {
      return jsonDecode('"${match.group(1)!}"') as String;
    } catch (_) {
      return match.group(1) ?? '';
    }
  }

  Map<String, dynamic> _extractStyleObject(String source) {
    final int styleKey = source.indexOf('"style"');
    if (styleKey < 0) return <String, dynamic>{};
    final int objectStart = source.indexOf('{', styleKey);
    if (objectStart < 0) return <String, dynamic>{};
    int depth = 0;
    bool inString = false;
    bool escaped = false;
    for (int i = objectStart; i < source.length; i++) {
      final String ch = source[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == '\\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          try {
            return jsonDecode(source.substring(objectStart, i + 1))
                as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        }
      }
    }
    return <String, dynamic>{};
  }

  /// Removes ```json ... ``` wrappers a VLM may wrap its answer in.
  String stripMarkdownFences(String input) {
    String s = input.trim();
    // Remove ```json ... ``` wrapper.
    if (s.startsWith('```')) {
      final int firstNewline = s.indexOf('\n');
      if (firstNewline >= 0) {
        s = s.substring(firstNewline + 1);
      }
      if (s.endsWith('```')) {
        s = s.substring(0, s.length - 3);
      }
      s = s.trim();
    }
    return s;
  }

  /// Normalizes a raw VLM bbox into the Ideogram `[y1, x1, y2, x2]` 0-1000
  /// format, or returns null when the box is missing/malformed/degenerate.
  ///
  /// [vlmEmitsXyxy] declares the order the VLM actually emitted: most output
  /// `[x1, y1, x2, y2]` (the default), some obey the yxyx instruction. Either
  /// way this rounds, clamps to [0, 1000], orders the corners, reorders to the
  /// Ideogram `[y1, x1, y2, x2]` format, and drops zero-area boxes so
  /// downstream SAM box-prompts, palette extraction, and overlays never
  /// receive garbage. The stored result is always yxyx.
  List<int>? normalizeBbox(dynamic raw, {bool vlmEmitsXyxy = true}) {
    if (raw is! List || raw.length != 4) return null;
    final List<int> v;
    try {
      v = raw.map((dynamic e) => (e as num).round().clamp(0, 1000)).toList();
    } catch (_) {
      // Non-numeric entries — not a usable bbox.
      return null;
    }
    // Interpret the four values by the orientation the VLM emitted. The output
    // is always [y1, x1, y2, x2]; only the input interpretation changes.
    int x1;
    int y1;
    int x2;
    int y2;
    if (vlmEmitsXyxy) {
      x1 = v[0];
      y1 = v[1];
      x2 = v[2];
      y2 = v[3];
    } else {
      // VLM obeyed the yxyx instruction: input is [y1, x1, y2, x2].
      y1 = v[0];
      x1 = v[1];
      y2 = v[2];
      x2 = v[3];
    }
    if (x2 < x1) {
      final int t = x1;
      x1 = x2;
      x2 = t;
    }
    if (y2 < y1) {
      final int t = y1;
      y1 = y2;
      y2 = t;
    }
    // Drop zero-area boxes (clamp may have collapsed them to a line/point).
    if (x2 <= x1 || y2 <= y1) return null;
    return <int>[y1, x1, y2, x2];
  }

  VlmAnalysis parseAnalysisJson(
    Map<String, dynamic> json, {
    bool vlmEmitsXyxy = true,
  }) {
    // Parse style.
    final Map<String, dynamic> styleJson =
        json['style'] as Map<String, dynamic>;
    final VlmStyle style = VlmStyle(
      medium: styleJson['medium'] as String? ?? 'photograph',
      aesthetics: styleJson['aesthetics'] as String? ?? '',
      lighting: styleJson['lighting'] as String? ?? '',
      photoOrArt: styleJson['photo_or_art'] as String? ?? '',
    );

    // Parse objects — normalize bbox format to [y1, x1, y2, x2].
    final List<dynamic> objectsJson =
        json['objects'] as List<dynamic>? ?? <dynamic>[];
    final List<VlmObject> objects = objectsJson.map((dynamic o) {
      final Map<String, dynamic> obj = o as Map<String, dynamic>;
      // Prefer the explicit `type` field (official schema). Fall back to the
      // legacy `has_text` flag so older responses still parse.
      String type = (obj['type'] as String?)?.toLowerCase() ?? '';
      if (type != 'text' && type != 'obj') {
        type = (obj['has_text'] as bool?) == true ? 'text' : 'obj';
      }
      return VlmObject(
        name: obj['name'] as String? ?? '',
        desc: obj['desc'] as String? ?? '',
        type: type,
        text: (obj['text'] as String?) ?? (obj['visible_text'] as String?),
        // VLMs mostly return [x1, y1, x2, y2]; some obey the yxyx instruction.
        // [vlmEmitsXyxy] tells the normalizer how to interpret the four values.
        // Either way the stored Ideogram format is [y1, x1, y2, x2]; degenerate
        // boxes become null so they don't poison SAM box-prompts, palette
        // extraction, or overlays.
        bbox: normalizeBbox(obj['bbox'], vlmEmitsXyxy: vlmEmitsXyxy),
      );
    }).toList();

    return VlmAnalysis(
      highLevelDescription: json['high_level_description'] as String? ?? '',
      style: style,
      background: json['background'] as String? ?? '',
      objects: objects,
    );
  }
}

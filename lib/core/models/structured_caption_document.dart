import 'dart:convert';

import 'ideogram_caption.dart';
import 'moss_layout_caption.dart';

/// The structured caption format a caption string uses.
enum CaptionFormat { plain, ideogram, moss }

/// Detects the format of a caption string from its content. Ideogram JSON has
/// top-level `high_level_description` / `compositional_deconstruction`; MOSS
/// layout JSON has `summary` + `items`; everything else is a plain caption.
CaptionFormat detectCaptionFormat(String text) {
  if (IdeogramCaption.isIdeogramJson(text)) {
    return CaptionFormat.ideogram;
  }
  if (MossLayoutCaption.isMossJson(text)) {
    return CaptionFormat.moss;
  }
  return CaptionFormat.plain;
}

/// Format-agnostic view of a stored structured caption. Exactly one branch is
/// populated; [format] says which.
sealed class StructuredCaptionDocument {
  const StructuredCaptionDocument();

  CaptionFormat get format;

  /// Compact, key-order-pinned storage string (identical to what the
  /// per-format `toJsonString()` emits).
  String toJsonString();

  static StructuredCaptionDocument? tryParse(String text) {
    switch (detectCaptionFormat(text)) {
      case CaptionFormat.ideogram:
        return IdeogramDocument(
          caption: IdeogramCaption.fromJson(
            jsonDecode(text) as Map<String, dynamic>,
          ),
        );
      case CaptionFormat.moss:
        return MossDocument(
          caption: MossLayoutCaption.fromJson(
            jsonDecode(text) as Map<String, dynamic>,
          ),
        );
      case CaptionFormat.plain:
        return null;
    }
  }
}

class IdeogramDocument extends StructuredCaptionDocument {
  const IdeogramDocument({required this.caption});

  final IdeogramCaption caption;

  @override
  CaptionFormat get format => CaptionFormat.ideogram;

  @override
  String toJsonString() => caption.toJsonString();

  @override
  bool operator ==(Object other) =>
      other is IdeogramDocument && other.caption == caption;

  @override
  int get hashCode => caption.hashCode;
}

class MossDocument extends StructuredCaptionDocument {
  const MossDocument({required this.caption});

  final MossLayoutCaption caption;

  /// True when the stored JSON explicitly carries the native centered
  /// markers — such documents are trainer prompts, not editable drafts.
  bool get isNative => caption.isNativeMarked;

  @override
  CaptionFormat get format => CaptionFormat.moss;

  @override
  String toJsonString() => caption.toJsonString();

  @override
  bool operator ==(Object other) =>
      other is MossDocument && other.caption == caption;

  @override
  int get hashCode => caption.hashCode;
}

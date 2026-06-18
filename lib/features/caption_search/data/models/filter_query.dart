import 'dart:convert';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../structured_captioning/data/models/ideogram_caption.dart';
import '../../../structured_captioning/presentation/widgets/ideogram_caption_summary_card.dart';

/// Parsed result of a search query containing both filter expressions
/// and a plain text component.
class ParsedFilterQuery extends Equatable {
  const ParsedFilterQuery({
    required this.filters,
    required this.plainTextQuery,
  });

  /// Structured filter expressions parsed from the query.
  final List<FilterExpression> filters;

  /// Leftover plain text not part of any filter expression.
  final String plainTextQuery;

  @override
  List<Object?> get props => <Object?>[filters, plainTextQuery];
}

/// Base class for all structured caption filter expressions.
sealed class FilterExpression extends Equatable {
  const FilterExpression();

  /// Evaluates this filter against a raw caption string.
  ///
  /// Returns `true` if the caption matches this filter's criteria.
  bool evaluate(String captionText);

  /// Parses the caption as an [IdeogramCaption] if it is valid JSON,
  /// otherwise returns `null`.
  static IdeogramCaption? tryParseCaption(String text) {
    if (!IdeogramCaptionSummaryCard.isIdeogramJson(text)) return null;
    try {
      return IdeogramCaption.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Matches captions that have at least one element of the given type.
///
/// Example: `:has:text:`, `:has:obj:`
class HasTypeFilter extends FilterExpression {
  const HasTypeFilter({required this.elementType});

  /// "obj" or "text".
  final String elementType;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    return caption.compositionalDeconstruction.elements.any(
      (IdeogramElement e) => e.type == elementType,
    );
  }

  @override
  List<Object?> get props => <Object?>[elementType];
}

/// Matches captions that have at least one element with a bounding box.
///
/// Example: `:has:bbox:`
class HasBboxFilter extends FilterExpression {
  const HasBboxFilter();

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    return caption.compositionalDeconstruction.elements.any(
      (IdeogramElement e) => e.bbox != null,
    );
  }

  @override
  List<Object?> get props => <Object?>[];
}

/// Matches captions where at least two element bboxes overlap by at least
/// [threshold] (intersection-over-union). Useful for finding duplicate
/// detections of the same item that VLMs sometimes emit.
///
/// Examples: `:dupbbox:` (default [defaultDuplicateBboxThreshold]),
/// `:dupbbox:0.5:`
class DuplicateBboxFilter extends FilterExpression {
  const DuplicateBboxFilter({this.threshold = defaultDuplicateBboxThreshold});

  /// Default IoU threshold used by `:dupbbox:` (flag form).
  static const double defaultDuplicateBboxThreshold = 0.7;

  /// Minimum IoU for two bboxes to count as duplicates.
  /// `1.0` = identical, `0.0` = no overlap.
  final double threshold;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;

    final List<List<int>> bboxes = caption
        .compositionalDeconstruction.elements
        .where(
          (IdeogramElement e) => e.bbox != null && e.bbox!.length == 4,
        )
        .map((IdeogramElement e) => e.bbox!)
        .toList();

    if (bboxes.length < 2) return false;

    for (int i = 0; i < bboxes.length; i++) {
      for (int j = i + 1; j < bboxes.length; j++) {
        if (iou(bboxes[i], bboxes[j]) >= threshold) {
          return true;
        }
      }
    }
    return false;
  }

  /// Computes intersection-over-union for two bboxes stored as
  /// `[y1, x1, y2, x2]` in 0-1000 normalized coordinates.
  static double iou(List<int> a, List<int> b) {
    final int interY1 = math.max(a[0], b[0]);
    final int interX1 = math.max(a[1], b[1]);
    final int interY2 = math.min(a[2], b[2]);
    final int interX2 = math.min(a[3], b[3]);

    if (interY2 <= interY1 || interX2 <= interX1) return 0.0;

    final int intersection = (interY2 - interY1) * (interX2 - interX1);
    final int areaA = (a[2] - a[0]) * (a[3] - a[1]);
    final int areaB = (b[2] - b[0]) * (b[3] - b[1]);
    final int union = areaA + areaB - intersection;

    if (union <= 0) return 0.0;
    return intersection / union;
  }

  @override
  List<Object?> get props => <Object?>[threshold];
}

/// Matches captions with a specific number of compositional elements.
///
/// Examples: `:elements:3:`, `:elements:>2:`, `:elements:>=3:`
class ElementCountFilter extends FilterExpression {
  const ElementCountFilter({required this.count, required this.operator});

  /// The count to compare against.
  final int count;

  /// '=', '>', or '>='.
  final String operator;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    final int actual = caption.compositionalDeconstruction.elements.length;
    switch (operator) {
      case '=':
        return actual == count;
      case '>':
        return actual > count;
      case '>=':
        return actual >= count;
      default:
        return false;
    }
  }

  @override
  List<Object?> get props => <Object?>[count, operator];
}

/// Matches captions whose style medium equals the given value.
///
/// Example: `:medium:photograph:`
class MediumFilter extends FilterExpression {
  const MediumFilter({required this.medium});

  final String medium;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    return caption.styleDescription.medium.toLowerCase() ==
        medium.toLowerCase();
  }

  @override
  List<Object?> get props => <Object?>[medium];
}

/// Matches captions whose high-level description contains the pattern.
///
/// Example: `:desc:sunset:`
class DescriptionFilter extends FilterExpression {
  const DescriptionFilter({required this.pattern});

  final String pattern;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    return caption.highLevelDescription.toLowerCase().contains(
      pattern.toLowerCase(),
    );
  }

  @override
  List<Object?> get props => <Object?>[pattern];
}

/// Matches captions where any style field contains the pattern.
///
/// Example: `:style:dramatic:`
class StyleFilter extends FilterExpression {
  const StyleFilter({required this.pattern});

  final String pattern;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    final String lowerPattern = pattern.toLowerCase();
    final IdeogramStyleDescription style = caption.styleDescription;
    return style.aesthetics.toLowerCase().contains(lowerPattern) ||
        style.lighting.toLowerCase().contains(lowerPattern) ||
        style.medium.toLowerCase().contains(lowerPattern) ||
        (style.photo?.toLowerCase().contains(lowerPattern) ?? false) ||
        (style.artStyle?.toLowerCase().contains(lowerPattern) ?? false);
  }

  @override
  List<Object?> get props => <Object?>[pattern];
}

/// Matches captions whose background description contains the pattern.
///
/// Example: `:bg:forest:`
class BackgroundFilter extends FilterExpression {
  const BackgroundFilter({required this.pattern});

  final String pattern;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    return caption.compositionalDeconstruction.background
        .toLowerCase()
        .contains(pattern.toLowerCase());
  }

  @override
  List<Object?> get props => <Object?>[pattern];
}

/// Matches captions where any element desc or text field contains the pattern.
///
/// Example: `:element:cat:`
class ElementDescFilter extends FilterExpression {
  const ElementDescFilter({required this.pattern});

  final String pattern;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    final String lowerPattern = pattern.toLowerCase();
    return caption.compositionalDeconstruction.elements.any(
      (IdeogramElement e) =>
          e.desc.toLowerCase().contains(lowerPattern) ||
          (e.text?.toLowerCase().contains(lowerPattern) ?? false),
    );
  }

  @override
  List<Object?> get props => <Object?>[pattern];
}

/// Matches captions whose color palette (style or any element) contains
/// a color perceptually similar to the given hex color.
///
/// Example: `:color:#FF0000:`
class ColorFilter extends FilterExpression {
  const ColorFilter({required this.hexColor});

  final String hexColor;

  @override
  bool evaluate(String captionText) {
    final IdeogramCaption? caption = FilterExpression.tryParseCaption(
      captionText,
    );
    if (caption == null) return false;
    final String normalized = hexColor.toUpperCase();
    // Check style palette
    if (caption.styleDescription.colorPalette.any(
      (String c) => c.toUpperCase() == normalized,
    )) {
      return true;
    }
    // Check element palettes
    return caption.compositionalDeconstruction.elements.any(
      (IdeogramElement e) =>
          e.colorPalette?.any((String c) => c.toUpperCase() == normalized) ??
          false,
    );
  }

  @override
  List<Object?> get props => <Object?>[hexColor];
}

/// Matches captions that are valid Ideogram JSON.
///
/// Example: `:structured:`
class IsStructuredFilter extends FilterExpression {
  const IsStructuredFilter();

  @override
  bool evaluate(String captionText) {
    return IdeogramCaptionSummaryCard.isIdeogramJson(captionText);
  }

  @override
  List<Object?> get props => <Object?>[];
}

/// Matches captions that are plain text (not Ideogram JSON).
///
/// Example: `:plain:`
class IsPlainFilter extends FilterExpression {
  const IsPlainFilter();

  @override
  bool evaluate(String captionText) {
    if (captionText.trim().isEmpty) return false;
    return !IdeogramCaptionSummaryCard.isIdeogramJson(captionText);
  }

  @override
  List<Object?> get props => <Object?>[];
}

/// Matches images that have no caption at all.
///
/// Example: `:nocaption:`
class NoCaptionFilter extends FilterExpression {
  const NoCaptionFilter();

  @override
  bool evaluate(String captionText) {
    return captionText.trim().isEmpty;
  }

  @override
  List<Object?> get props => <Object?>[];
}

import 'package:flutter/material.dart';

/// A TextEditingController that highlights search query matches in the text.
class HighlightTextController extends TextEditingController {
  /// The search query to highlight. If empty, no highlighting is applied.
  String highlightQuery;

  /// Whether the search is case-sensitive.
  bool caseSensitive;

  HighlightTextController({
    super.text,
    this.highlightQuery = '',
    this.caseSensitive = false,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (highlightQuery.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final List<TextSpan> spans = <TextSpan>[];
    final String text = this.text;
    final String query = caseSensitive ? highlightQuery : highlightQuery.toLowerCase();
    final String searchTarget = caseSensitive ? text : text.toLowerCase();

    int lastIndex = 0;
    int matchIndex = searchTarget.indexOf(query);

    while (matchIndex != -1) {
      // Add non-matching text before the match
      if (matchIndex > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, matchIndex)));
      }

      // Add highlighted matching text
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchIndex + query.length),
          style: const TextStyle(
            backgroundColor: Color(0xFF66BB6A), // Green highlight
            color: Colors.white,
          ),
        ),
      );

      lastIndex = matchIndex + query.length;
      matchIndex = searchTarget.indexOf(query, lastIndex);
    }

    // Add remaining non-matching text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return TextSpan(style: style, children: spans);
  }
}

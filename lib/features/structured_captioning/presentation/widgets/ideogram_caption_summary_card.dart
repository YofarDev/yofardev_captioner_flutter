import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/ideogram_caption.dart';

/// Compact summary card for Ideogram JSON captions on the main screen.
///
/// Shows a quick-glance view: truncated description, style tags,
/// element count, and an edit button.
class IdeogramCaptionSummaryCard extends StatelessWidget {
  const IdeogramCaptionSummaryCard({
    required this.jsonString,
    required this.imageFile,
    required this.activeCategory,
    super.key,
  });

  final String jsonString;
  final File imageFile;
  final String activeCategory;

  /// Checks whether a string is a valid Ideogram JSON caption.
  static bool isIdeogramJson(String text) {
    if (!text.trimLeft().startsWith('{')) return false;
    try {
      final Map<String, dynamic> data =
          jsonDecode(text) as Map<String, dynamic>;
      return data.containsKey('high_level_description') &&
          data.containsKey('compositional_deconstruction');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final IdeogramCaption caption;
    try {
      caption = IdeogramCaption.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    } catch (_) {
      return Text(
        jsonString,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: Colors.white70,
        ),
      );
    }

    final int objCount = caption.compositionalDeconstruction.elements
        .where((IdeogramElement e) => e.type == 'obj')
        .length;
    final int textCount = caption.compositionalDeconstruction.elements
        .where((IdeogramElement e) => e.type == 'text')
        .length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // High-level description (truncated)
          SizedBox(
            width: double.infinity,
            child: Text(
              caption.highLevelDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.4,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),

          if (caption.styleDescription.medium.isNotEmpty ||
              caption.styleDescription.aesthetics.isNotEmpty ||
              caption.styleDescription.lighting.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _formatTags(caption.styleDescription),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 0.3,
                ),
              ),
            ),

          // Background
          SizedBox(
            width: double.infinity,
            child: Text(
              caption.compositionalDeconstruction.background,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.3,
                color: Colors.white60,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Element count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$objCount obj${objCount != 1 ? 's' : ''}'
              '${textCount > 0 ? ' · $textCount text' : ''}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.tealAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTags(IdeogramStyleDescription style) {
  final List<String> parts = <String>[
    if (style.medium.isNotEmpty) style.medium,
    if (style.aesthetics.isNotEmpty) style.aesthetics,
    if (style.lighting.isNotEmpty) style.lighting,
  ];
  return parts.join(' · ');
}

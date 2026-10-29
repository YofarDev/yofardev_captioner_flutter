import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/moss_layout_caption.dart';
import '../../../../core/models/structured_caption_document.dart';

/// Compact summary card for structured JSON captions (Ideogram or MOSS) on
/// the main screen.
///
/// Shows a quick-glance view: truncated description, style/meta tags,
/// element count, and an edit button. Renders whichever layout matches the
/// detected caption format.
class StructuredCaptionSummaryCard extends StatelessWidget {
  const StructuredCaptionSummaryCard({
    required this.jsonString,
    required this.imageFile,
    required this.activeCategory,
    super.key,
  });

  final String jsonString;
  final File imageFile;
  final String activeCategory;

  @override
  Widget build(BuildContext context) {
    switch (detectCaptionFormat(jsonString)) {
      case CaptionFormat.moss:
        return _buildMoss();
      case CaptionFormat.ideogram:
        return _buildIdeogram();
      case CaptionFormat.plain:
        return Text(
          jsonString,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Colors.white70,
          ),
        );
    }
  }

  Widget _buildIdeogram() {
    final IdeogramCaption caption;
    try {
      caption = IdeogramCaption.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    } catch (_) {
      return _fallbackText();
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
          _DescriptionLine(text: caption.highLevelDescription),
          const SizedBox(height: 6),
          if (caption.styleDescription.medium.isNotEmpty ||
              caption.styleDescription.aesthetics.isNotEmpty ||
              caption.styleDescription.lighting.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _formatIdeogramTags(caption.styleDescription),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _tagStyle,
              ),
            ),
          _DescriptionLine(
            text: caption.compositionalDeconstruction.background,
            small: true,
          ),
          const SizedBox(height: 6),
          _CountBadge(objCount: objCount, textCount: textCount),
        ],
      ),
    );
  }

  Widget _buildMoss() {
    final MossLayoutCaption caption;
    try {
      caption = MossLayoutCaption.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    } catch (_) {
      return _fallbackText();
    }

    final int objCount = caption.items
        .where((MossItem e) => e.label != 'text')
        .length;
    final int textCount = caption.items
        .where((MossItem e) => e.label == 'text')
        .length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _DescriptionLine(text: caption.summary.caption)),
              _CompiledPromptCopyButton(caption: caption),
            ],
          ),
          const SizedBox(height: 6),
          if (caption.summary.meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                caption.summary.meta.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _tagStyle,
              ),
            ),
          const SizedBox(height: 2),
          _CountBadge(
            objCount: objCount,
            textCount: textCount,
            extra: caption.summary.canvas,
          ),
        ],
      ),
    );
  }

  static const TextStyle _tagStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    color: Colors.white38,
    letterSpacing: 0.3,
  );

  Widget _fallbackText() => Text(
    jsonString,
    style: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      color: Colors.white70,
    ),
  );
}

class _DescriptionLine extends StatelessWidget {
  const _DescriptionLine({required this.text, this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        maxLines: small ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: small ? 12 : 13,
          height: 1.4,
          color: small ? Colors.white60 : Colors.white,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.objCount,
    required this.textCount,
    this.extra,
  });

  final int objCount;
  final int textCount;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.teal.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$objCount obj${objCount != 1 ? 's' : ''}'
        '${textCount > 0 ? ' · $textCount text' : ''}'
        '${extra != null ? ' · $extra' : ''}',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: Colors.tealAccent,
        ),
      ),
    );
  }
}

/// Copies the compiled one-line MOSS prompt (centered yxyx boxes, no canvas
/// metadata) — the ready-to-paste form for the MOSS-Image generator.
class _CompiledPromptCopyButton extends StatelessWidget {
  const _CompiledPromptCopyButton({required this.caption});

  final MossLayoutCaption caption;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copy compiled MOSS prompt',
      child: InkWell(
        onTap: () {
          try {
            Clipboard.setData(
              ClipboardData(text: caption.toCompiledPromptString()),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Compiled MOSS prompt copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          } catch (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot compile: a bbox is out of bounds'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.copy, size: 14, color: Colors.white38),
        ),
      ),
    );
  }
}

String _formatIdeogramTags(IdeogramStyleDescription style) {
  final List<String> parts = <String>[
    if (style.medium.isNotEmpty) style.medium,
    if (style.aesthetics.isNotEmpty) style.aesthetics,
    if (style.lighting.isNotEmpty) style.lighting,
  ];
  return parts.join(' · ');
}

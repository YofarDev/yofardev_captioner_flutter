import 'dart:convert';

import 'package:flutter/material.dart';

/// Displays an Ideogram4 structured caption in a readable, expandable layout.
///
/// Falls back to raw text if parsing fails.
class IdeogramCaptionView extends StatelessWidget {
  const IdeogramCaptionView({required this.jsonString, super.key});

  final String jsonString;

  /// Returns true if [text] looks like an Ideogram4 JSON caption.
  static bool isIdeogramJson(String text) {
    final String trimmed = text.trim();
    return trimmed.startsWith('{') &&
        trimmed.contains('"high_level_description"') &&
        trimmed.contains('"compositional_deconstruction"');
  }

  @override
  Widget build(BuildContext context) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(jsonString) as Map<String, dynamic>;
      return _buildStructuredView(data);
    } catch (_) {
      // Fallback: show raw text
      return Text(
        jsonString,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          height: 1.5,
          color: Colors.white70,
        ),
      );
    }
  }

  Widget _buildStructuredView(Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // High-level description
          _buildSectionHeader(Icons.image_outlined, 'Description'),
          const SizedBox(height: 4),
          Text(
            data['high_level_description'] as String? ?? '',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              height: 1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Style section
          if (data['style_description'] != null)
            _buildStyleSection(
              data['style_description'] as Map<String, dynamic>,
            ),

          // Background
          if (data['compositional_deconstruction'] != null) ...<Widget>[
            _buildSectionHeader(Icons.landscape, 'Background'),
            const SizedBox(height: 4),
            Text(
              (data['compositional_deconstruction']
                          as Map<String, dynamic>)['background']
                      as String? ??
                  '',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.5,
                color: Colors.white.withAlpha(200),
              ),
            ),
            const SizedBox(height: 16),

            // Elements
            _buildElementsSection(
              (data['compositional_deconstruction']
                          as Map<String, dynamic>)['elements']
                      as List<dynamic>? ??
                  <dynamic>[],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: Colors.teal[300]),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.teal[300],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStyleSection(Map<String, dynamic> style) {
    final String medium = style['medium'] as String? ?? '';
    final String aesthetics = style['aesthetics'] as String? ?? '';
    final String lighting = style['lighting'] as String? ?? '';
    final String photoOrArt =
        (style['photo'] ?? style['art_style']) as String? ?? '';
    final List<dynamic> palette =
        style['color_palette'] as List<dynamic>? ?? <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSectionHeader(Icons.palette_outlined, 'Style'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            _buildChip(Icons.camera_alt_outlined, medium),
            if (aesthetics.isNotEmpty)
              _buildChip(Icons.auto_awesome, aesthetics),
            if (lighting.isNotEmpty)
              _buildChip(Icons.wb_sunny_outlined, lighting),
            if (photoOrArt.isNotEmpty) _buildChip(Icons.lens, photoOrArt),
          ],
        ),
        if (palette.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _buildColorPalette(palette.cast<String>()),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPalette(List<String> colors) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: colors.map((String hex) {
        final Color color = _parseHexColor(hex);
        return Tooltip(
          message: hex,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildElementsSection(List<dynamic> elements) {
    if (elements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSectionHeader(Icons.layers_outlined, 'Elements'),
        const SizedBox(height: 8),
        ...elements.map(
          (dynamic e) => _buildElementCard(e as Map<String, dynamic>),
        ),
      ],
    );
  }

  Widget _buildElementCard(Map<String, dynamic> element) {
    final String type = element['type'] as String? ?? 'obj';
    final String desc = element['desc'] as String? ?? '';
    final String? text = element['text'] as String?;
    final List<dynamic>? bbox = element['bbox'] as List<dynamic>?;
    final List<dynamic>? palette = element['color_palette'] as List<dynamic>?;

    final bool isText = type == 'text';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isText ? Colors.amber.withAlpha(15) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isText
              ? Colors.amber.withAlpha(60)
              : Colors.white.withAlpha(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isText ? Icons.text_fields : Icons.crop_free,
                size: 14,
                color: isText ? Colors.amber[300] : Colors.teal[300],
              ),
              const SizedBox(width: 6),
              Text(
                isText ? 'TEXT' : 'OBJECT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isText ? Colors.amber[300] : Colors.teal[300],
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (bbox != null && bbox.length == 4)
                Text(
                  '${bbox[0]},${bbox[1]} → ${bbox[2]},${bbox[3]}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Inter',
                    color: Colors.white38,
                  ),
                ),
            ],
          ),
          if (text != null && text.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '"$text"',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.amber[100],
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.4,
              color: Colors.white.withAlpha(180),
            ),
          ),
          if (palette != null && palette.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _buildColorPalette(palette.cast<String>()),
          ],
        ],
      ),
    );
  }

  Color _parseHexColor(String hex) {
    try {
      final String cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

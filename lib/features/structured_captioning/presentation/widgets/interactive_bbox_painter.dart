import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/ideogram_caption.dart';
import '../utils/bbox_utils.dart';

/// CustomPainter for interactive bounding box overlays.
class InteractiveBboxPainter extends CustomPainter {
  const InteractiveBboxPainter({
    required this.elements,
    required this.resolvedBboxes,
    required this.hiddenIndices,
    required this.selectedIndex,
    required this.paintedRect,
    required this.boxColors,
    this.drawingRect,
  });

  final List<IdeogramElement> elements;

  /// Parallel to [elements]: the bbox to render for each element, or null
  /// when the element has no bbox. The caller (canvas) decides whether
  /// each entry is the saved (VLM) bbox or the SAM3 bbox based on the
  /// editor's display mode.
  final List<List<int>?> resolvedBboxes;

  final Set<int> hiddenIndices;
  final int? selectedIndex;
  final Rect paintedRect;
  final List<Color> boxColors;
  final Rect? drawingRect;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw non-selected bboxes first.
    for (int i = 0; i < elements.length; i++) {
      if (hiddenIndices.contains(i)) continue;
      if (i == selectedIndex) continue; // selected drawn last (on top)
      final IdeogramElement el = elements[i];
      if (i >= resolvedBboxes.length) continue;
      final List<int>? bbox = resolvedBboxes[i];
      if (bbox == null) continue;

      final Rect rect = bboxToRect(bbox, paintedRect);
      final Color color = boxColors[i % boxColors.length];
      _drawBbox(canvas, rect, color, el, false);
    }

    // Draw the selected bbox last so it and its label sit on top.
    final int? selected = selectedIndex;
    if (selected != null &&
        !hiddenIndices.contains(selected) &&
        selected < elements.length) {
      final IdeogramElement el = elements[selected];
      final List<int>? bbox =
          selected < resolvedBboxes.length ? resolvedBboxes[selected] : null;
      if (bbox != null) {
        final Rect rect = bboxToRect(bbox, paintedRect);
        final Color color = boxColors[selected % boxColors.length];
        _drawBbox(canvas, rect, color, el, true);
      }
    }

    // Draw the new-bbox drawing rect (dashed)
    if (drawingRect != null) {
      _drawDashedRect(canvas, drawingRect!);
    }
  }

  void _drawBbox(
    Canvas canvas,
    Rect rect,
    Color color,
    IdeogramElement element,
    bool isSelected,
  ) {
    final double strokeWidth = isSelected ? 2.5 : 1.5;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Draw filled background — stronger fill on selected to highlight area.
    final Paint fillPaint = Paint()
      ..color = color.withValues(alpha: isSelected ? 0.3 : 0.06)
      ..style = PaintingStyle.fill;

    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, paint);

    // Label: full description when selected, first sentence otherwise.
    final String label = element.type == 'text'
        ? '"${element.text ?? 'text'}"'
        : (isSelected ? element.desc : element.desc.split('.').first);
    _drawLabel(canvas, rect, label, color, expanded: isSelected);

    // Corner handles for selected element
    if (isSelected) {
      _drawCornerHandles(canvas, rect, color);
    }
  }

  void _drawLabel(
    Canvas canvas,
    Rect rect,
    String label,
    Color bgColor, {
    bool expanded = false,
  }) {
    if (label.isEmpty) return;

    const double padW = 4.0;
    const double padH = 4.0;
    final double availW = rect.width - padW;
    final double availH = rect.height - padH;

    // Skip when the bbox is too small to hold a readable label.
    if (availW < 12 || availH < 8) return;

    final String displayText = expanded
        ? label
        : (label.length > 30 ? '${label.substring(0, 30)}...' : label);
    final double fontSize = expanded ? 10 : 9;
    final int maxDesiredLines = expanded ? 6 : 1;

    final TextStyle style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      fontFamily: 'Inter',
      color: getContrastColor(bgColor),
    );

    // Measure a single line so we can compute how many complete lines fit
    // inside the bbox height without expanding it.
    final TextPainter probe = TextPainter(
      text: TextSpan(text: displayText, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: availW);
    final double lineHeight = probe.height > 0 ? probe.height : fontSize * 1.3;
    int linesThatFit = (availH / lineHeight).floor();
    if (linesThatFit < 1) linesThatFit = 1;
    if (linesThatFit > maxDesiredLines) linesThatFit = maxDesiredLines;

    final TextPainter tp = TextPainter(
      text: TextSpan(text: displayText, style: style),
      textDirection: TextDirection.ltr,
      maxLines: linesThatFit,
      ellipsis: '…',
    )..layout(maxWidth: availW);

    // Label background — clamped to the bbox bounds.
    final Rect labelRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      math.min(tp.width + padW, rect.width),
      math.min(tp.height + padH, rect.height),
    );
    final Paint labelBg = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    // Clip to the bbox so neither text nor background can overflow it.
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(2)),
      labelBg,
    );
    tp.paint(canvas, Offset(rect.left + padW / 2, rect.top + padH / 2));
    canvas.restore();
  }

  void _drawCornerHandles(Canvas canvas, Rect rect, Color color) {
    const double handleRadius = 5.0;
    final Paint handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint handleStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final List<Offset> corners = <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (final Offset corner in corners) {
      canvas.drawCircle(corner, handleRadius, handlePaint);
      canvas.drawCircle(corner, handleRadius, handleStroke);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect) {
    const double dashLen = 6.0;
    const double gapLen = 4.0;
    final Paint paint = Paint()
      ..color = Colors.tealAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw each side as dashed line
    _drawDashedLine(
      canvas,
      rect.topLeft,
      rect.topRight,
      paint,
      dashLen,
      gapLen,
    );
    _drawDashedLine(
      canvas,
      rect.topRight,
      rect.bottomRight,
      paint,
      dashLen,
      gapLen,
    );
    _drawDashedLine(
      canvas,
      rect.bottomRight,
      rect.bottomLeft,
      paint,
      dashLen,
      gapLen,
    );
    _drawDashedLine(
      canvas,
      rect.bottomLeft,
      rect.topLeft,
      paint,
      dashLen,
      gapLen,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double totalLen = dx * dx + dy * dy;
    if (totalLen == 0) return;
    final double length = totalLen > 0 ? ui.Offset(dx, dy).distance : 0;
    if (length == 0) return;

    final double unitX = dx / length;
    final double unitY = dy / length;

    double drawn = 0;
    bool drawing = true;
    while (drawn < length) {
      final double segment = drawing ? dashLen : gapLen;
      final double endDrawn = (drawn + segment).clamp(0, length);

      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + unitX * drawn, start.dy + unitY * drawn),
          Offset(start.dx + unitX * endDrawn, start.dy + unitY * endDrawn),
          paint,
        );
      }
      drawn = endDrawn;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant InteractiveBboxPainter oldDelegate) {
    return elements != oldDelegate.elements ||
        resolvedBboxes != oldDelegate.resolvedBboxes ||
        hiddenIndices != oldDelegate.hiddenIndices ||
        selectedIndex != oldDelegate.selectedIndex ||
        paintedRect != oldDelegate.paintedRect ||
        drawingRect != oldDelegate.drawingRect;
  }
}

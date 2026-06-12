import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/ideogram_caption.dart';
import '../utils/bbox_utils.dart';

/// CustomPainter for interactive bounding box overlays.
class InteractiveBboxPainter extends CustomPainter {
  const InteractiveBboxPainter({
    required this.elements,
    required this.hiddenIndices,
    required this.selectedIndex,
    required this.paintedRect,
    required this.boxColors,
    this.drawingRect,
  });

  final List<IdeogramElement> elements;
  final Set<int> hiddenIndices;
  final int? selectedIndex;
  final Rect paintedRect;
  final List<Color> boxColors;
  final Rect? drawingRect;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw each visible element bbox
    for (int i = 0; i < elements.length; i++) {
      if (hiddenIndices.contains(i)) continue;
      final IdeogramElement el = elements[i];
      if (el.bbox == null) continue;

      final Rect rect = bboxToRect(el.bbox!, paintedRect);
      final bool isSelected = i == selectedIndex;
      final Color color = boxColors[i % boxColors.length];

      _drawBbox(canvas, rect, color, el, isSelected);
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

    // Draw filled background
    final Paint fillPaint = Paint()
      ..color = color.withAlpha(isSelected ? 30 : 15)
      ..style = PaintingStyle.fill;

    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, paint);

    // Label
    final String label = element.type == 'text'
        ? '"${element.text ?? 'text'}"'
        : element.desc.split('.').first;
    _drawLabel(canvas, rect, label, color);

    // Corner handles for selected element
    if (isSelected) {
      _drawCornerHandles(canvas, rect, color);
    }
  }

  void _drawLabel(Canvas canvas, Rect rect, String label, Color bgColor) {
    if (label.isEmpty) return;

    final TextSpan span = TextSpan(
      text: label.length > 30 ? '${label.substring(0, 30)}...' : label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
        color: getContrastColor(bgColor),
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: rect.width - 4);

    // Label background
    final Rect labelRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      tp.width + 8,
      tp.height + 4,
    );
    final Paint labelBg = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(2)),
      labelBg,
    );

    tp.paint(canvas, Offset(rect.left + 4, rect.top + 2));
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
        hiddenIndices != oldDelegate.hiddenIndices ||
        selectedIndex != oldDelegate.selectedIndex ||
        paintedRect != oldDelegate.paintedRect ||
        drawingRect != oldDelegate.drawingRect;
  }
}

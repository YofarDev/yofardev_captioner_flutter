import 'package:flutter/material.dart';

/// Shared bounding-box coordinate utilities.
///
/// Ideogram4 uses [y1, x1, y2, x2] in 0-1000 normalized space.
/// These functions convert between that space and screen-pixel rects,
/// accounting for [BoxFit.contain] letterboxing/pillarboxing.

/// Standard color palette for bbox overlays.
const List<Color> kBboxColors = <Color>[
  Color(0xFF26A69A), // teal
  Color(0xFFFFCA28), // amber
  Color(0xFFEC407A), // pink
  Color(0xFF42A5F5), // light blue
  Color(0xFFFFA726), // orange
  Color(0xFF9CCC65), // lime
  Color(0xFFAB47BC), // purple
  Color(0xFF26C6DA), // cyan
];

/// Calculates the rect where an image is actually painted by [BoxFit.contain].
Rect getContainRect(Size container, Size imageSize) {
  final double imageAspect = imageSize.width / imageSize.height;
  final double containerAspect = container.width / container.height;

  double paintedW;
  double paintedH;

  if (containerAspect > imageAspect) {
    // Container wider → image fills height, centered horizontally.
    paintedH = container.height;
    paintedW = paintedH * imageAspect;
  } else {
    // Container taller → image fills width, centered vertically.
    paintedW = container.width;
    paintedH = paintedW / imageAspect;
  }

  final double offsetX = (container.width - paintedW) / 2;
  final double offsetY = (container.height - paintedH) / 2;

  return Rect.fromLTWH(offsetX, offsetY, paintedW, paintedH);
}

/// Converts Ideogram [y1, x1, y2, x2] (0-1000) to a screen [Rect]
/// within the [paintedRect].
Rect bboxToRect(List<int> bbox, Rect paintedRect) {
  final double left = paintedRect.left + (bbox[1] / 1000) * paintedRect.width;
  final double top = paintedRect.top + (bbox[0] / 1000) * paintedRect.height;
  final double right = paintedRect.left + (bbox[3] / 1000) * paintedRect.width;
  final double bottom = paintedRect.top + (bbox[2] / 1000) * paintedRect.height;
  return Rect.fromLTRB(left, top, right, bottom);
}

/// Converts a screen [Rect] back to Ideogram [y1, x1, y2, x2] (0-1000)
/// within the [paintedRect].
List<int> rectToBbox(Rect rect, Rect paintedRect) {
  final int y1 = ((rect.top - paintedRect.top) / paintedRect.height * 1000)
      .round()
      .clamp(0, 1000);
  final int x1 = ((rect.left - paintedRect.left) / paintedRect.width * 1000)
      .round()
      .clamp(0, 1000);
  final int y2 = ((rect.bottom - paintedRect.top) / paintedRect.height * 1000)
      .round()
      .clamp(0, 1000);
  final int x2 = ((rect.right - paintedRect.left) / paintedRect.width * 1000)
      .round()
      .clamp(0, 1000);
  return <int>[y1, x1, y2, x2];
}

/// Returns a contrasting text color (black/white) for a given background.
Color getContrastColor(Color bg) {
  final double luminance = bg.computeLuminance();
  return luminance > 0.5 ? Colors.black87 : Colors.white;
}

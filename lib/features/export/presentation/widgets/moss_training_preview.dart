import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// One pane of the MOSS training preview: renders the source image cropped
/// to the given view window (the whole frame for the source pane, the
/// scale+crop window for the prepared pane) with matching boxes overlaid.
///
/// Geometry contract (Codex rev-3 finding 2): ONE contain scale
/// `min(maxWidth/viewWidth, maxHeight/viewHeight)` drives BOTH axes for the
/// image positioning AND the box painter, in the same centered, clipped
/// viewport — for portrait, landscape, and square view windows alike, pixels
/// and boxes can never misalign.
class MossCropPreviewPane extends StatelessWidget {
  const MossCropPreviewPane({
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.viewLeft,
    required this.viewTop,
    required this.viewWidth,
    required this.viewHeight,
    required this.boxes,
    required this.label,
    super.key,
  });

  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final int viewLeft;
  final int viewTop;
  final int viewWidth;
  final int viewHeight;
  final List<List<int>?> boxes;
  final String label;

  /// The single contain scale for the view window inside the pane.
  @visibleForTesting
  static double containScale({
    required double maxWidth,
    required double maxHeight,
    required int viewWidth,
    required int viewHeight,
  }) {
    if (viewWidth <= 0 || viewHeight <= 0) {
      return 1.0;
    }
    final double sx = maxWidth / viewWidth;
    final double sy = maxHeight / viewHeight;
    return sx < sy ? sx : sy;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.white38),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double scale = containScale(
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                  viewWidth: viewWidth,
                  viewHeight: viewHeight,
                );
                final double viewportWidth = viewWidth * scale;
                final double viewportHeight = viewHeight * scale;
                return Center(
                  child: SizedBox(
                    width: viewportWidth,
                    height: viewportHeight,
                    child: ClipRect(
                      child: Stack(
                        children: <Widget>[
                          Positioned(
                            left: -viewLeft.toDouble() * scale,
                            top: -viewTop.toDouble() * scale,
                            width: imageWidth * scale,
                            height: imageHeight * scale,
                            child: Image.file(
                              File(imagePath),
                              fit: BoxFit.fill,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? st,
                                  ) => const ColoredBox(
                                    color: Colors.white10,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white24,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: TrainingBoxPainter(
                                viewWidth: viewWidth,
                                viewHeight: viewHeight,
                                boxes: boxes,
                                // The SAME scale the image is drawn with,
                                // so boxes and pixels share one transform.
                                scale: scale,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws boxes in view coordinates using the pane's single contain scale.
class TrainingBoxPainter extends CustomPainter {
  const TrainingBoxPainter({
    required this.viewWidth,
    required this.viewHeight,
    required this.boxes,
    required this.scale,
  });

  final int viewWidth;
  final int viewHeight;
  final List<List<int>?> boxes;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = lightPink;
    for (final List<int>? b in boxes) {
      if (b == null || b.length != 4) {
        continue;
      }
      canvas.drawRect(
        Rect.fromLTRB(b[0] * scale, b[1] * scale, b[2] * scale, b[3] * scale),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrainingBoxPainter oldDelegate) =>
      oldDelegate.boxes != boxes ||
      oldDelegate.scale != scale ||
      oldDelegate.viewWidth != viewWidth ||
      oldDelegate.viewHeight != viewHeight;
}

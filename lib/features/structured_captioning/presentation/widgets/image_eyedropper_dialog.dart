import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../data/services/color_extraction_service.dart';
import '../utils/bbox_utils.dart';

/// Opens a full-screen eyedropper over [imageFile] and returns the picked
/// color as "#RRGGBB", or null if cancelled.
///
/// When [elementBbox] is supplied (Ideogram `[y1, x1, y2, x2]` in 0-1000
/// normalized coords) it is drawn as a highlight to guide the user; picking is
/// still allowed anywhere on the image.
Future<String?> showImageEyedropperDialog(
  BuildContext context, {
  required File imageFile,
  List<int>? elementBbox,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black,
    builder: (BuildContext _) => _EyedropperDialog(
      imageFile: imageFile,
      elementBbox: elementBbox,
    ),
  );
}

class _EyedropperDialog extends StatefulWidget {
  const _EyedropperDialog({required this.imageFile, this.elementBbox});

  final File imageFile;
  final List<int>? elementBbox;

  @override
  State<_EyedropperDialog> createState() => _EyedropperDialogState();
}

class _EyedropperDialogState extends State<_EyedropperDialog> {
  img.Image? _image;
  Size? _imageSize;
  String? _error;
  Offset? _cursor;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final Uint8List bytes = await widget.imageFile.readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) {
        if (mounted) setState(() => _error = 'Could not load image');
        return;
      }
      // Bake EXIF orientation so sampled pixels match how Flutter renders the
      // image (Image.file applies EXIF rotation; img.decodeImage does not).
      decoded = img.bakeOrientation(decoded);
      final img.Image rgb =
          decoded.numChannels >= 3 ? decoded : decoded.convert(numChannels: 3);
      if (mounted) {
        setState(() {
          _image = rgb;
          _imageSize = Size(rgb.width.toDouble(), rgb.height.toDouble());
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load image');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape):
              () => Navigator.of(context).pop(),
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              'Pick a color from the image',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
    if (_image == null || _imageSize == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size container = Size(constraints.maxWidth, constraints.maxHeight);
        final Rect paintedRect = getContainRect(container, _imageSize!);
        return GestureDetector(
          key: const ValueKey<String>('eyedropper-body'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => _pick(d.localPosition, paintedRect),
          child: MouseRegion(
            onHover: (PointerHoverEvent e) =>
                setState(() => _cursor = e.localPosition),
            onExit: (_) => setState(() => _cursor = null),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Container(color: Colors.black),
                Positioned.fill(
                  child: Image.file(widget.imageFile, fit: BoxFit.contain),
                ),
                if (widget.elementBbox != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BboxHighlightPainter(
                        rect: bboxToRect(widget.elementBbox!, paintedRect),
                      ),
                    ),
                  ),
                if (_cursor != null && paintedRect.contains(_cursor!))
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LoupePainter(
                        image: _image!,
                        paintedRect: paintedRect,
                        cursor: _cursor!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pick(Offset local, Rect paintedRect) {
    if (!paintedRect.contains(local)) return; // ignore letterbox taps
    final img.Image image = _image!;
    final Point<int> pixel =
        localToImagePixel(local, paintedRect, _imageSize!);
    Navigator.of(context)
        .pop(ColorExtractionService().hexAt(image, pixel.x, pixel.y));
  }
}

/// Draws a thin outline around the element's bbox as a picking guide.
class _BboxHighlightPainter extends CustomPainter {
  _BboxHighlightPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _BboxHighlightPainter old) => old.rect != rect;
}

/// Magnifier loupe that follows the cursor, plus a live hex readout.
class _LoupePainter extends CustomPainter {
  _LoupePainter({
    required this.image,
    required this.paintedRect,
    required this.cursor,
  });

  final img.Image image;
  final Rect paintedRect;
  final Offset cursor;

  static const int _half = 7; // 15x15 sampled grid
  static const double _cell = 14.0; // displayed size of each sampled pixel

  @override
  void paint(Canvas canvas, Size size) {
    final Point<int> center = localToImagePixel(
      cursor,
      paintedRect,
      Size(image.width.toDouble(), image.height.toDouble()),
    );
    final int cx = center.x;
    final int cy = center.y;

    const double loupe = (_half * 2 + 1) * _cell;
    final Offset topLeft = _placeLoupe(cursor, loupe, size);

    // Sampled pixels.
    final Paint cellPaint = Paint();
    for (int dy = -_half; dy <= _half; dy++) {
      for (int dx = -_half; dx <= _half; dx++) {
        final int px = (cx + dx).clamp(0, image.width - 1);
        final int py = (cy + dy).clamp(0, image.height - 1);
        final img.Pixel p = image.getPixel(px, py);
        cellPaint.color =
            Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt());
        canvas.drawRect(
          Rect.fromLTWH(
            topLeft.dx + (dx + _half) * _cell,
            topLeft.dy + (dy + _half) * _cell,
            _cell,
            _cell,
          ),
          cellPaint,
        );
      }
    }
    // Loupe border.
    canvas.drawRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, loupe, loupe),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Center cell highlight.
    canvas.drawRect(
      Rect.fromLTWH(
        topLeft.dx + _half * _cell,
        topLeft.dy + _half * _cell,
        _cell,
        _cell,
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Crosshair ring at the actual cursor.
    canvas.drawCircle(
      cursor,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Live hex readout below the loupe.
    final img.Pixel cp = image.getPixel(cx, cy);
    final String hex =
        '#${cp.r.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${cp.g.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${cp.b.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}';
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: hex,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Offset hexPos = Offset(topLeft.dx, topLeft.dy + loupe + 4);
    canvas.drawRect(
      Rect.fromLTWH(hexPos.dx, hexPos.dy, tp.width + 12, tp.height + 6),
      Paint()..color = Colors.black.withAlpha(160),
    );
    tp.paint(canvas, Offset(hexPos.dx + 6, hexPos.dy + 3));
  }

  /// Places the loupe offset from the cursor, flipping sides near edges.
  Offset _placeLoupe(Offset cursor, double loupe, Size canvas) {
    double dx = cursor.dx + 24;
    double dy = cursor.dy + 24;
    if (dx + loupe > canvas.width) dx = cursor.dx - loupe - 24;
    if (dy + loupe > canvas.height) dy = cursor.dy - loupe - 24;
    return Offset(dx < 0 ? 0 : dx, dy < 0 ? 0 : dy);
  }

  @override
  bool shouldRepaint(covariant _LoupePainter old) =>
      old.cursor != cursor ||
      old.image != image ||
      old.paintedRect != paintedRect;
}

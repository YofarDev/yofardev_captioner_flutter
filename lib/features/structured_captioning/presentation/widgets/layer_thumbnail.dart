import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Async thumbnail cropper with in-memory cache.
///
/// Uses Flutter's native image decoder ([ui.instantiateImageCodec]) which
/// supports all platform-native formats (JPEG, PNG, HEIC, WebP, etc.)
/// on the main thread — the crop is small enough (48×48) that the
/// performance difference vs an isolate is negligible.
class LayerThumbnail extends StatefulWidget {
  const LayerThumbnail({
    required this.imageFile,
    required this.bbox,
    required this.cacheKey,
    this.accentColor = Colors.teal,
    super.key,
  });

  final File imageFile;
  final List<int> bbox;
  final String cacheKey;
  final Color accentColor;

  @override
  State<LayerThumbnail> createState() => _LayerThumbnailState();
}

class _LayerThumbnailState extends State<LayerThumbnail> {
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LayerThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cacheKey != oldWidget.cacheKey) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_cache.containsKey(widget.cacheKey)) {
      if (mounted) {
        setState(() {
          _bytes = _cache[widget.cacheKey];
        });
      }
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final Uint8List fileBytes = await widget.imageFile.readAsBytes();

      // Decode with Flutter's native codec (supports HEIC etc.).
      final ui.Codec codec = await ui.instantiateImageCodec(fileBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image fullImage = frame.image;
      final double imgW = fullImage.width.toDouble();
      final double imgH = fullImage.height.toDouble();

      // Normalized [y1, x1, y2, x2] → pixel coords.
      final List<int> bbox = widget.bbox;
      final double py1 = (bbox[0] / 1000 * imgH).clamp(0, imgH - 1);
      final double px1 = (bbox[1] / 1000 * imgW).clamp(0, imgW - 1);
      final double py2 = (bbox[2] / 1000 * imgH).clamp(py1 + 1, imgH);
      final double px2 = (bbox[3] / 1000 * imgW).clamp(px1 + 1, imgW);

      // Render cropped region centered in 48×48, maintaining aspect ratio,
      // with black fill for the unused area.
      final double cropW = px2 - px1;
      final double cropH = py2 - py1;
      final double scale = cropW > cropH ? 48.0 / cropW : 48.0 / cropH;
      final double dstW = cropW * scale;
      final double dstH = cropH * scale;
      final double dx = (48.0 - dstW) / 2;
      final double dy = (48.0 - dstH) / 2;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 48, 48),
        Paint()..color = const Color(0xFF000000),
      );
      canvas.drawImageRect(
        fullImage,
        Rect.fromLTRB(px1, py1, px2, py2),
        Rect.fromLTWH(dx, dy, dstW, dstH),
        Paint(),
      );
      final ui.Picture picture = recorder.endRecording();
      final ui.Image thumbnail = await picture.toImage(48, 48);

      // Encode to PNG bytes.
      final ByteData? pngBytes = await thumbnail.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (pngBytes != null) {
        final Uint8List result = pngBytes.buffer.asUint8List();
        _cache[widget.cacheKey] = result;
        if (mounted) {
          setState(() {
            _bytes = result;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: widget.accentColor.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: widget.accentColor.withAlpha(100),
            ),
          ),
        ),
      );
    }

    if (_bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(_bytes!, width: 36, height: 36, fit: BoxFit.cover),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: widget.accentColor.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.image_not_supported,
        size: 16,
        color: widget.accentColor.withAlpha(80),
      ),
    );
  }
}

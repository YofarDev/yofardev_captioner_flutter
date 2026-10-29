import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/models/moss_layout_caption.dart';
import '../../../../core/utils/image_header_parser.dart';
import '../utils/bbox_utils.dart';

/// Displays an image with bounding box overlays from an Ideogram4 JSON caption.
///
/// Bounding boxes are drawn as colored outlines with labels, accounting for
/// [BoxFit.contain] letterboxing/pillarboxing.
class BboxOverlayImage extends StatefulWidget {
  const BboxOverlayImage({
    required this.imageFile,
    required this.captionJson,
    super.key,
  });

  final File imageFile;
  final String captionJson;

  @override
  State<BboxOverlayImage> createState() => _BboxOverlayImageState();
}

class _BboxOverlayImageState extends State<BboxOverlayImage> {
  int? _imageWidth;
  // ignore: use_late_for_private_fields_and_variables
  int? _imageHeight;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  @override
  void didUpdateWidget(covariant BboxOverlayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageFile.path != oldWidget.imageFile.path) {
      _loaded = false;
      _loadImageDimensions();
    }
  }

  Future<void> _loadImageDimensions() async {
    // Header-only parse: a full decode here would stall the UI thread for
    // large images, and only the dimensions are needed for bbox mapping.
    final ImageHeader? header = await ImageHeaderParser.parseFile(
      widget.imageFile,
    );
    if (!mounted) {
      return;
    }
    if (header != null) {
      setState(() {
        _imageWidth = header.width;
        _imageHeight = header.height;
        _loaded = true;
      });
    } else {
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<BboxElement> elements = BboxElement.parse(widget.captionJson);

    if (!_loaded || _imageWidth == null || elements.isEmpty) {
      return Image.file(widget.imageFile, fit: BoxFit.contain);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size containerSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final Rect paintedRect = _getContainRect(
          containerSize,
          Size(_imageWidth!.toDouble(), _imageHeight!.toDouble()),
        );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.file(widget.imageFile, fit: BoxFit.contain),
            ..._buildBboxOverlays(paintedRect, elements),
          ],
        );
      },
    );
  }

  /// Calculates the rect where the image is actually painted by BoxFit.contain.
  Rect _getContainRect(Size container, Size imageSize) {
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

  List<Widget> _buildBboxOverlays(Rect painted, List<BboxElement> elements) {
    return elements.asMap().entries.map((MapEntry<int, BboxElement> entry) {
      final int index = entry.key;
      final BboxElement el = entry.value;
      final Color color = kBboxColors[index % kBboxColors.length];

      // Convert 0-1000 normalized [y1, x1, y2, x2] to pixel offsets
      // within the painted rect.
      final double left = painted.left + (el.x1 / 1000) * painted.width;
      final double top = painted.top + (el.y1 / 1000) * painted.height;
      final double right = painted.left + (el.x2 / 1000) * painted.width;
      final double bottom = painted.top + (el.y2 / 1000) * painted.height;

      return Positioned(
        left: left,
        top: top,
        width: right - left,
        height: bottom - top,
        child: _BboxBox(color: color, element: el),
      );
    }).toList();
  }
}

/// A single colored bbox overlay with label.
class _BboxBox extends StatelessWidget {
  const _BboxBox({required this.color, required this.element});

  final Color color;
  final BboxElement element;

  @override
  Widget build(BuildContext context) {
    final String label = element.type == 'text'
        ? '"${element.label ?? 'text'}"'
        : element.desc.split('.').first;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: element.desc,
        preferBelow: true,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  bottomRight: Radius.circular(4),
                ),
              ),
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getContrastColor(color),
                  fontFamily: 'Inter',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns black or white text color based on background luminance.
  Color _getContrastColor(Color bg) {
    final double luminance = bg.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

/// A parsed bounding box element from Ideogram4 JSON.
class BboxElement {
  const BboxElement({
    required this.type,
    this.label,
    required this.desc,
    required this.y1,
    required this.x1,
    required this.y2,
    required this.x2,
  });

  final String type;
  final String? label;
  final String desc;

  /// Normalized 0-1000 coordinates.
  final double y1;
  final double x1;
  final double y2;
  final double x2;

  /// Parses elements from an Ideogram4 JSON string, or from a MOSS layout
  /// draft (absolute-pixel xyxy bboxes normalized against the canvas
  /// width/height embedded in the JSON).
  static List<BboxElement> parse(String json) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(json) as Map<String, dynamic>;
      if (MossLayoutCaption.isNativeMossJson(json)) {
        // Native centered yxyx coordinates are not draft boxes — drawing
        // them through the top-left parser would render garbage overlays.
        return <BboxElement>[];
      }
      if (MossLayoutCaption.isMossJson(json)) {
        return _parseMoss(data);
      }
      final Map<String, dynamic> decomp =
          data['compositional_deconstruction'] as Map<String, dynamic>;
      final List<dynamic> elements =
          decomp['elements'] as List<dynamic>? ?? <dynamic>[];

      return elements
          .where((dynamic e) => (e as Map<String, dynamic>)['bbox'] != null)
          .map((dynamic e) {
            final Map<String, dynamic> map = e as Map<String, dynamic>;
            final List<dynamic> bbox = map['bbox'] as List<dynamic>;
            return BboxElement(
              type: map['type'] as String? ?? 'obj',
              label: map['type'] == 'text'
                  ? (map['text'] as String? ?? 'text')
                  : null,
              desc: map['desc'] as String? ?? '',
              y1: (bbox[0] as num).toDouble(),
              x1: (bbox[1] as num).toDouble(),
              y2: (bbox[2] as num).toDouble(),
              x2: (bbox[3] as num).toDouble(),
            );
          })
          .toList();
    } catch (_) {
      return <BboxElement>[];
    }
  }

  static List<BboxElement> _parseMoss(Map<String, dynamic> data) {
    final MossLayoutCaption caption = MossLayoutCaption.fromJson(data);
    final int width = caption.width <= 0 ? 1 : caption.width;
    final int height = caption.height <= 0 ? 1 : caption.height;
    return caption.items.where((MossItem item) => item.bbox != null).map((
      MossItem item,
    ) {
      final List<int> bbox = item.bbox!;
      final bool isText = item.label == 'text';
      return BboxElement(
        type: isText ? 'text' : 'obj',
        label: isText ? (item.text ?? 'text') : null,
        desc: item.caption,
        y1: (bbox[1] / height * 1000).clamp(0, 1000).toDouble(),
        x1: (bbox[0] / width * 1000).clamp(0, 1000).toDouble(),
        y2: (bbox[3] / height * 1000).clamp(0, 1000).toDouble(),
        x2: (bbox[2] / width * 1000).clamp(0, 1000).toDouble(),
      );
    }).toList();
  }
}

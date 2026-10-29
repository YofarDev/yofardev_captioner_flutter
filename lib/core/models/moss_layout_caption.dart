import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../utils/compact_json.dart';

/// MOSS-Image layout caption model (https://github.com/OpenMOSS/MOSS-Image).
///
/// Produces the exact JSON structure expected by the MOSS-Image layout draft
/// via [toJson], plus the compiled one-line prompt via
/// [toCompiledPromptString]. Canvas dimensions must be positive multiples of
/// 16; bounding boxes are absolute pixels in `[x1, y1, x2, y2]` order from the
/// canvas top-left.
class MossLayoutCaption extends Equatable {
  const MossLayoutCaption({
    required this.width,
    required this.height,
    required this.summary,
    required this.items,
    this.bboxCoordSpace,
    this.bboxFormat,
  });

  /// Canvas width in pixels. Positive multiple of 16.
  final int width;

  /// Canvas height in pixels. Positive multiple of 16.
  final int height;

  final MossSummary summary;
  final List<MossItem> items;

  /// Coordinate markers read from the source JSON, when present. Drafts
  /// written by this app may omit them (legacy shape); native compiled
  /// prompts carry `abs_centralized`/`yxyx`.
  final String? bboxCoordSpace;
  final String? bboxFormat;

  /// True when the source JSON explicitly declared the native centered
  /// contract (`abs_centralized` + `yxyx`).
  bool get isNativeMarked =>
      bboxCoordSpace == 'abs_centralized' && bboxFormat == 'yxyx';

  factory MossLayoutCaption.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> summary =
        json['summary'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return MossLayoutCaption(
      width: (json['width'] as num?)?.toInt() ?? 1024,
      height: (json['height'] as num?)?.toInt() ?? 1024,
      summary: MossSummary.fromJson(summary),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((dynamic e) => MossItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <MossItem>[],
      bboxCoordSpace: json['bbox_coord_space'] as String?,
      bboxFormat: json['bbox_format'] as String?,
    );
  }

  MossLayoutCaption copyWith({
    int? width,
    int? height,
    MossSummary? summary,
    List<MossItem>? items,
    String? bboxCoordSpace,
    String? bboxFormat,
  }) {
    return MossLayoutCaption(
      width: width ?? this.width,
      height: height ?? this.height,
      summary: summary ?? this.summary,
      items: items ?? this.items,
      bboxCoordSpace: bboxCoordSpace ?? this.bboxCoordSpace,
      bboxFormat: bboxFormat ?? this.bboxFormat,
    );
  }

  /// Checks whether a string is a MOSS layout JSON caption. Requires the
  /// `summary` object (with a caption) and the flat `items` array — neither
  /// key exists in Ideogram JSON, so detection cannot collide.
  static bool isMossJson(String text) {
    if (!text.trimLeft().startsWith('{')) return false;
    try {
      final Map<String, dynamic> data =
          jsonDecode(text) as Map<String, dynamic>;
      final Object? summary = data['summary'];
      return summary is Map<String, dynamic> &&
          summary['caption'] is String &&
          data['items'] is List<dynamic>;
    } catch (_) {
      return false;
    }
  }

  /// True when [text] is MOSS JSON explicitly marked with the native
  /// centered contract (`abs_centralized` + `yxyx`). Native prompts must not
  /// be opened through the top-left draft parser — see
  /// `parseMossNative` in `moss_format.dart`.
  static bool isNativeMossJson(String text) {
    if (!isMossJson(text)) return false;
    try {
      final Map<String, dynamic> data =
          jsonDecode(text) as Map<String, dynamic>;
      return data['bbox_coord_space'] == 'abs_centralized' &&
          data['bbox_format'] == 'yxyx';
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the text is valid MOSS JSON but its summary caption is
  /// null or empty.
  static bool hasEmptySummaryCaption(String text) {
    if (!isMossJson(text)) return false;
    try {
      final Map<String, dynamic> data =
          jsonDecode(text) as Map<String, dynamic>;
      final Map<String, dynamic> summary =
          data['summary'] as Map<String, dynamic>;
      final String? caption = summary['caption'] as String?;
      return caption == null || caption.isEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Produces compact JSON matching the MOSS layout draft schema.
  String toJsonString() => compactJson(toJson());

  /// Compiles the layout into the ready-to-paste MOSS prompt: one physical
  /// line of JSON with no canvas metadata (width/height/coord-space markers
  /// dropped) and bounding boxes converted to integer centered `yxyx` order.
  /// Fractional draft edges are floored (left/top) and ceiled (right/bottom)
  /// before subtracting the canvas center. Out-of-bounds boxes throw — the
  /// MOSS compiler rejects them rather than clipping, and so do we.
  String toCompiledPromptString() {
    final double halfWidth = width / 2;
    final double halfHeight = height / 2;
    final List<Map<String, dynamic>> compiledItems = items.map((MossItem item) {
      final List<int>? bbox = item.bbox;
      if (bbox == null || bbox.length != 4) {
        throw StateError('MOSS item without a 4-number bbox');
      }
      final int x1 = bbox[0];
      final int y1 = bbox[1];
      final int x2 = bbox[2];
      final int y2 = bbox[3];
      if (x1 < 0 ||
          y1 < 0 ||
          x2 > width ||
          y2 > height ||
          x1 >= x2 ||
          y1 >= y2) {
        throw StateError('MOSS bbox out of bounds: $bbox');
      }
      return <String, dynamic>{
        'label': item.label,
        'caption': item.caption,
        if (item.label == 'text') 'text': item.text ?? '',
        'bbox': <int>[
          (y1 - halfHeight).floor(),
          (x1 - halfWidth).floor(),
          (y2 - halfHeight).ceil(),
          (x2 - halfWidth).ceil(),
        ],
        if (item.tags.isNotEmpty) 'tags': item.tags,
        if (item.palette.isNotEmpty) 'palette': item.palette,
      };
    }).toList();
    final Map<String, dynamic> compiled = <String, dynamic>{
      'summary': summary.toJson(),
      'items': compiledItems,
    };
    return compactJson(compiled);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'width': width,
    'height': height,
    // Preserve the contract the caption actually follows — never rewrite a
    // native prompt's markers to draft markers on the way out.
    'bbox_coord_space': bboxCoordSpace ?? 'abs',
    'bbox_format': bboxFormat ?? 'xyxy',
    'summary': summary.toJson(),
    'items': items.map((MossItem e) => e.toJson()).toList(),
  };

  @override
  List<Object?> get props => <Object?>[
    width,
    height,
    summary,
    items,
    bboxCoordSpace,
    bboxFormat,
  ];
}

class MossSummary extends Equatable {
  const MossSummary({
    required this.caption,
    this.meta = const <String>[],
    this.canvas,
    this.palette = const <String>[],
  });

  final String caption;

  /// Medium/genre tag strings.
  final List<String> meta;

  /// `"single"`, `"multi_panel"` or `"collage"`, when meaningful.
  final String? canvas;

  final List<String> palette;

  factory MossSummary.fromJson(Map<String, dynamic> json) {
    return MossSummary(
      caption: json['caption'] as String? ?? '',
      meta:
          (json['meta'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList() ??
          <String>[],
      canvas: json['canvas'] as String?,
      palette:
          (json['palette'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList() ??
          <String>[],
    );
  }

  MossSummary copyWith({
    String? caption,
    List<String>? meta,
    String? canvas,
    bool clearCanvas = false,
    List<String>? palette,
  }) {
    return MossSummary(
      caption: caption ?? this.caption,
      meta: meta ?? this.meta,
      canvas: clearCanvas ? null : (canvas ?? this.canvas),
      palette: palette ?? this.palette,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (meta.isNotEmpty) 'meta': meta,
    if (canvas != null) 'canvas': canvas,
    'caption': caption,
    if (palette.isNotEmpty) 'palette': palette,
  };

  @override
  List<Object?> get props => <Object?>[caption, meta, canvas, palette];
}

class MossItem extends Equatable {
  const MossItem({
    this.label = 'object',
    required this.caption,
    this.text,
    this.bbox,
    this.tags = const <String>[],
    this.palette = const <String>[],
  });

  /// `"object"`, `"character"` or `"text"`.
  final String label;
  final String caption;

  /// Exact visible characters. Required for `text` items; line breaks are
  /// literal `\n`.
  final String? text;

  /// `[x1, y1, x2, y2]` in absolute pixels from the canvas top-left.
  final List<int>? bbox;
  final List<String> tags;
  final List<String> palette;

  factory MossItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawBbox = json['bbox'] as List<dynamic>?;
    return MossItem(
      label: json['label'] as String? ?? 'object',
      caption: json['caption'] as String? ?? '',
      text: json['text'] as String?,
      bbox: rawBbox?.map((dynamic e) => (e as num).toInt()).toList(),
      tags:
          (json['tags'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList() ??
          <String>[],
      palette:
          (json['palette'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList() ??
          <String>[],
    );
  }

  MossItem copyWith({
    String? label,
    String? caption,
    String? text,
    bool clearText = false,
    List<int>? bbox,
    bool clearBbox = false,
    List<String>? tags,
    List<String>? palette,
  }) {
    return MossItem(
      label: label ?? this.label,
      caption: caption ?? this.caption,
      text: clearText ? null : (text ?? this.text),
      bbox: clearBbox ? null : (bbox ?? this.bbox),
      tags: tags ?? this.tags,
      palette: palette ?? this.palette,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'caption': caption,
    if (label == 'text') 'text': text ?? '',
    'bbox': bbox,
    if (tags.isNotEmpty) 'tags': tags,
    if (palette.isNotEmpty) 'palette': palette,
  };

  @override
  List<Object?> get props => <Object?>[
    label,
    caption,
    text,
    bbox,
    tags,
    palette,
  ];
}

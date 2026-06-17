import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Ideogram4-compatible structured caption model.
///
/// Produces the exact JSON structure expected by the Ideogram4 bounding-box
/// editor via [toJson].
class IdeogramCaption extends Equatable {
  const IdeogramCaption({
    required this.highLevelDescription,
    required this.styleDescription,
    required this.compositionalDeconstruction,
  });

  final String highLevelDescription;
  final IdeogramStyleDescription styleDescription;
  final IdeogramCompositionalDeconstruction compositionalDeconstruction;

  factory IdeogramCaption.fromJson(Map<String, dynamic> json) {
    return IdeogramCaption(
      highLevelDescription: json['high_level_description'] as String? ?? '',
      styleDescription: IdeogramStyleDescription.fromJson(
        json['style_description'] as Map<String, dynamic>? ??
            <String, dynamic>{},
      ),
      compositionalDeconstruction: IdeogramCompositionalDeconstruction.fromJson(
        json['compositional_deconstruction'] as Map<String, dynamic>? ??
            <String, dynamic>{},
      ),
    );
  }

  IdeogramCaption copyWith({
    String? highLevelDescription,
    IdeogramStyleDescription? styleDescription,
    IdeogramCompositionalDeconstruction? compositionalDeconstruction,
  }) {
    return IdeogramCaption(
      highLevelDescription: highLevelDescription ?? this.highLevelDescription,
      styleDescription: styleDescription ?? this.styleDescription,
      compositionalDeconstruction:
          compositionalDeconstruction ?? this.compositionalDeconstruction,
    );
  }

  /// Checks whether a string is a valid Ideogram JSON caption.
  static bool isIdeogramJson(String text) {
    if (!text.trimLeft().startsWith('{')) return false;
    try {
      final Map<String, dynamic> data =
          jsonDecode(text) as Map<String, dynamic>;
      return data.containsKey('high_level_description') &&
          data.containsKey('compositional_deconstruction');
    } catch (_) {
      return false;
    }
  }

  /// Produces compact JSON matching Ideogram4 schema.
  String toJsonString() => _compactJson(toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'high_level_description': highLevelDescription,
    'style_description': styleDescription.toJson(),
    'compositional_deconstruction': compositionalDeconstruction.toJson(),
  };

  @override
  List<Object?> get props => <Object?>[
    highLevelDescription,
    styleDescription,
    compositionalDeconstruction,
  ];
}

class IdeogramStyleDescription extends Equatable {
  const IdeogramStyleDescription({
    required this.aesthetics,
    required this.lighting,
    required this.medium,
    this.photo,
    this.artStyle,
    required this.colorPalette,
  });

  final String aesthetics;
  final String lighting;
  final String medium;

  /// Camera/lens details. Present only when [medium] is "photograph".
  final String? photo;

  /// Art style description. Present only when [medium] is NOT "photograph".
  final String? artStyle;

  final List<String> colorPalette;

  factory IdeogramStyleDescription.fromJson(Map<String, dynamic> json) {
    return IdeogramStyleDescription(
      aesthetics: json['aesthetics'] as String? ?? '',
      lighting: json['lighting'] as String? ?? '',
      medium: json['medium'] as String? ?? 'photograph',
      photo: json['photo'] as String?,
      artStyle: json['art_style'] as String?,
      colorPalette:
          (json['color_palette'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList() ??
          <String>[],
    );
  }

  IdeogramStyleDescription copyWith({
    String? aesthetics,
    String? lighting,
    String? medium,
    String? photo,
    bool clearPhoto = false,
    String? artStyle,
    bool clearArtStyle = false,
    List<String>? colorPalette,
  }) {
    return IdeogramStyleDescription(
      aesthetics: aesthetics ?? this.aesthetics,
      lighting: lighting ?? this.lighting,
      medium: medium ?? this.medium,
      photo: clearPhoto ? null : (photo ?? this.photo),
      artStyle: clearArtStyle ? null : (artStyle ?? this.artStyle),
      colorPalette: colorPalette ?? this.colorPalette,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'aesthetics': aesthetics,
      'lighting': lighting,
    };
    if (medium == 'photograph') {
      json['photo'] = photo ?? '';
    } else {
      json['art_style'] = artStyle ?? '';
    }
    json['medium'] = medium;
    json['color_palette'] = colorPalette;
    return json;
  }

  @override
  List<Object?> get props => <Object?>[
    aesthetics,
    lighting,
    medium,
    photo,
    artStyle,
    colorPalette,
  ];
}

class IdeogramElement extends Equatable {
  const IdeogramElement({
    required this.type,
    this.bbox,
    required this.desc,
    this.text,
    this.colorPalette,
  });

  /// "obj" or "text".
  final String type;

  /// [y1, x1, y2, x2] in 0-1000 normalized coordinates, or null.
  final List<int>? bbox;
  final String desc;

  /// Literal text content. Only set when [type] is "text".
  final String? text;

  final List<String>? colorPalette;

  factory IdeogramElement.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawBbox = json['bbox'] as List<dynamic>?;
    return IdeogramElement(
      type: json['type'] as String? ?? 'obj',
      bbox: rawBbox?.map((dynamic e) => (e as num).toInt()).toList(),
      desc: json['desc'] as String? ?? '',
      text: json['text'] as String?,
      colorPalette:
          (json['color_palette'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList() ??
          <String>[],
    );
  }

  IdeogramElement copyWith({
    String? type,
    List<int>? bbox,
    bool clearBbox = false,
    String? desc,
    String? text,
    bool clearText = false,
    List<String>? colorPalette,
    bool clearColorPalette = false,
  }) {
    return IdeogramElement(
      type: type ?? this.type,
      bbox: clearBbox ? null : (bbox ?? this.bbox),
      desc: desc ?? this.desc,
      text: clearText ? null : (text ?? this.text),
      colorPalette: clearColorPalette
          ? null
          : (colorPalette ?? this.colorPalette),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{'type': type};
    if (bbox != null) {
      json['bbox'] = bbox;
    }
    if (type == 'text') {
      json['text'] = text ?? '';
    }
    json['desc'] = desc;
    if (colorPalette != null && colorPalette!.isNotEmpty) {
      json['color_palette'] = colorPalette;
    }
    return json;
  }

  @override
  List<Object?> get props => <Object?>[type, bbox, desc, text, colorPalette];
}

class IdeogramCompositionalDeconstruction extends Equatable {
  const IdeogramCompositionalDeconstruction({
    required this.background,
    required this.elements,
  });

  final String background;
  final List<IdeogramElement> elements;

  factory IdeogramCompositionalDeconstruction.fromJson(
    Map<String, dynamic> json,
  ) {
    return IdeogramCompositionalDeconstruction(
      background: json['background'] as String? ?? '',
      elements:
          (json['elements'] as List<dynamic>?)
              ?.map(
                (dynamic e) =>
                    IdeogramElement.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          <IdeogramElement>[],
    );
  }

  IdeogramCompositionalDeconstruction copyWith({
    String? background,
    List<IdeogramElement>? elements,
  }) {
    return IdeogramCompositionalDeconstruction(
      background: background ?? this.background,
      elements: elements ?? this.elements,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'background': background,
    'elements': elements.map((IdeogramElement e) => e.toJson()).toList(),
  };

  @override
  List<Object?> get props => <Object?>[background, elements];
}

/// Produces compact JSON without extra whitespace.
String _compactJson(Map<String, dynamic> data) {
  final StringBuffer buffer = StringBuffer();
  _writeCompactJson(buffer, data);
  return buffer.toString();
}

void _writeCompactJson(StringBuffer buffer, Object? value) {
  if (value == null) {
    buffer.write('null');
  } else if (value is String) {
    buffer.write('"${_escapeString(value)}"');
  } else if (value is num || value is bool) {
    buffer.write(value);
  } else if (value is List) {
    buffer.write('[');
    for (int i = 0; i < value.length; i++) {
      if (i > 0) buffer.write(',');
      _writeCompactJson(buffer, value[i]);
    }
    buffer.write(']');
  } else if (value is Map<String, dynamic>) {
    buffer.write('{');
    int i = 0;
    for (final MapEntry<String, dynamic> entry in value.entries) {
      if (i > 0) buffer.write(',');
      buffer.write('"${_escapeString(entry.key)}":');
      _writeCompactJson(buffer, entry.value);
      i++;
    }
    buffer.write('}');
  }
}

String _escapeString(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r')
    .replaceAll('\t', '\\t');

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

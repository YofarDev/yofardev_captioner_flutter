import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'vlm_analysis.g.dart';

@JsonSerializable()
class VlmAnalysis extends Equatable {
  const VlmAnalysis({
    required this.highLevelDescription,
    required this.style,
    required this.background,
    required this.objects,
  });

  factory VlmAnalysis.fromJson(Map<String, dynamic> json) =>
      _$VlmAnalysisFromJson(json);

  final String highLevelDescription;
  final VlmStyle style;
  final String background;
  final List<VlmObject> objects;

  Map<String, dynamic> toJson() => _$VlmAnalysisToJson(this);

  @override
  List<Object?> get props => <Object?>[
    highLevelDescription,
    style,
    background,
    objects,
  ];
}

@JsonSerializable()
class VlmStyle extends Equatable {
  const VlmStyle({
    required this.medium,
    required this.aesthetics,
    required this.lighting,
    required this.photoOrArt,
  });

  factory VlmStyle.fromJson(Map<String, dynamic> json) =>
      _$VlmStyleFromJson(json);

  final String medium;
  final String aesthetics;
  final String lighting;

  @JsonKey(name: 'photo_or_art')
  final String photoOrArt;

  Map<String, dynamic> toJson() => _$VlmStyleToJson(this);

  @override
  List<Object?> get props => <Object?>[
    medium,
    aesthetics,
    lighting,
    photoOrArt,
  ];
}

@JsonSerializable()
class VlmObject extends Equatable {
  const VlmObject({
    required this.name,
    required this.desc,
    this.type = 'obj',
    this.text,
    this.bbox,
  });

  factory VlmObject.fromJson(Map<String, dynamic> json) =>
      _$VlmObjectFromJson(json);

  final String name;
  final String desc;

  /// Element type: `"obj"` or `"text"`. Mirrors the Ideogram4 schema's `type`
  /// field. The VLM classifies directly — an object that merely bears
  /// incidental text (a car with a license plate) is `"obj"`, while a text
  /// artifact (a sign, banner, logo-as-text) is `"text"`.
  @JsonKey(defaultValue: 'obj')
  final String type;

  /// Literal characters, only meaningful when [type] is `"text"`. Mirrors the
  /// Ideogram4 `text` field.
  final String? text;

  /// Bounding box as [y1, x1, y2, x2] in 0-1000 normalized coordinates.
  final List<int>? bbox;

  Map<String, dynamic> toJson() => _$VlmObjectToJson(this);

  @override
  List<Object?> get props => <Object?>[name, desc, type, text, bbox];
}

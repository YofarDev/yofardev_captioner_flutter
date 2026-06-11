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
    required this.hasText,
    this.visibleText,
    this.bbox,
  });

  factory VlmObject.fromJson(Map<String, dynamic> json) =>
      _$VlmObjectFromJson(json);

  final String name;
  final String desc;

  @JsonKey(name: 'has_text')
  final bool hasText;

  @JsonKey(name: 'visible_text')
  final String? visibleText;

  /// Bounding box as [y1, x1, y2, x2] in 0-1000 normalized coordinates.
  final List<int>? bbox;

  Map<String, dynamic> toJson() => _$VlmObjectToJson(this);

  @override
  List<Object?> get props => <Object?>[name, desc, hasText, visibleText, bbox];
}

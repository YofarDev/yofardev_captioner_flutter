// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vlm_analysis.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VlmAnalysis _$VlmAnalysisFromJson(Map<String, dynamic> json) => VlmAnalysis(
  highLevelDescription: json['highLevelDescription'] as String,
  style: VlmStyle.fromJson(json['style'] as Map<String, dynamic>),
  background: json['background'] as String,
  objects: (json['objects'] as List<dynamic>)
      .map((e) => VlmObject.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$VlmAnalysisToJson(VlmAnalysis instance) =>
    <String, dynamic>{
      'highLevelDescription': instance.highLevelDescription,
      'style': instance.style,
      'background': instance.background,
      'objects': instance.objects,
    };

VlmStyle _$VlmStyleFromJson(Map<String, dynamic> json) => VlmStyle(
  medium: json['medium'] as String,
  aesthetics: json['aesthetics'] as String,
  lighting: json['lighting'] as String,
  photoOrArt: json['photo_or_art'] as String,
);

Map<String, dynamic> _$VlmStyleToJson(VlmStyle instance) => <String, dynamic>{
  'medium': instance.medium,
  'aesthetics': instance.aesthetics,
  'lighting': instance.lighting,
  'photo_or_art': instance.photoOrArt,
};

VlmObject _$VlmObjectFromJson(Map<String, dynamic> json) => VlmObject(
  name: json['name'] as String,
  desc: json['desc'] as String,
  type: json['type'] as String? ?? 'obj',
  text: json['text'] as String?,
  bbox: (json['bbox'] as List<dynamic>?)
      ?.map((e) => (e as num).toInt())
      .toList(),
);

Map<String, dynamic> _$VlmObjectToJson(VlmObject instance) => <String, dynamic>{
  'name': instance.name,
  'desc': instance.desc,
  'type': instance.type,
  'text': instance.text,
  'bbox': instance.bbox,
};

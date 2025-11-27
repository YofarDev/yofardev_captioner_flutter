// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptionData _$CaptionDataFromJson(Map<String, dynamic> json) => CaptionData(
  id: json['id'] as String,
  filename: json['filename'] as String,
  caption: json['caption'] as String? ?? '',
  captionModel: json['captionModel'] as String?,
  captionTimestamp: json['captionTimestamp'] == null
      ? null
      : DateTime.parse(json['captionTimestamp'] as String),
  lastModified: json['lastModified'] == null
      ? null
      : DateTime.parse(json['lastModified'] as String),
);

Map<String, dynamic> _$CaptionDataToJson(CaptionData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'filename': instance.filename,
      'caption': instance.caption,
      'captionModel': instance.captionModel,
      'captionTimestamp': instance.captionTimestamp?.toIso8601String(),
      'lastModified': instance.lastModified?.toIso8601String(),
    };

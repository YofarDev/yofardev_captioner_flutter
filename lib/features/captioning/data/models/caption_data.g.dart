// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptionData _$CaptionDataFromJson(Map<String, dynamic> json) => CaptionData(
  id: json['id'] as String,
  filename: json['filename'] as String,
  captions: (json['captions'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, CaptionEntry.fromJson(e as Map<String, dynamic>)),
  ),
  lastModified: json['lastModified'] == null
      ? null
      : DateTime.parse(json['lastModified'] as String),
);

Map<String, dynamic> _$CaptionDataToJson(CaptionData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'filename': instance.filename,
      'captions': instance.captions.map((k, e) => MapEntry(k, e.toJson())),
      'lastModified': instance.lastModified?.toIso8601String(),
    };

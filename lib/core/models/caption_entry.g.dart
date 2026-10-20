// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptionEntry _$CaptionEntryFromJson(Map<String, dynamic> json) => CaptionEntry(
  text: json['text'] as String,
  model: json['model'] as String?,
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  isEdited: json['isEdited'] as bool? ?? false,
);

Map<String, dynamic> _$CaptionEntryToJson(CaptionEntry instance) =>
    <String, dynamic>{
      'text': instance.text,
      'model': instance.model,
      'timestamp': instance.timestamp?.toIso8601String(),
      'isEdited': instance.isEdited,
    };

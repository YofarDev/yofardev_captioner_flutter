// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption_database.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptionDatabase _$CaptionDatabaseFromJson(Map<String, dynamic> json) =>
    CaptionDatabase(
      images: (json['images'] as List<dynamic>)
          .map((e) => CaptionData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CaptionDatabaseToJson(CaptionDatabase instance) =>
    <String, dynamic>{
      'images': instance.images.map((e) => e.toJson()).toList(),
    };

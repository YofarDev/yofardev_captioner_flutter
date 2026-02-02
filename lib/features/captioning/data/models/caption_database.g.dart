// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption_database.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptionDatabase _$CaptionDatabaseFromJson(Map<String, dynamic> json) =>
    CaptionDatabase(
      version: (json['version'] as num?)?.toInt() ?? 2,
      categories: (json['categories'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      activeCategory: json['activeCategory'] as String?,
      images: (json['images'] as List<dynamic>)
          .map((e) => CaptionData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CaptionDatabaseToJson(CaptionDatabase instance) =>
    <String, dynamic>{
      'version': instance.version,
      'categories': instance.categories,
      'activeCategory': instance.activeCategory,
      'images': instance.images.map((e) => e.toJson()).toList(),
    };

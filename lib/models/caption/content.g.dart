// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Content _$ContentFromJson(Map<String, dynamic> json) => Content(
  type: json['type'] as String,
  text: json['text'] as String?,
  imageUrl: json['image_url'] == null
      ? null
      : ImageUrl.fromJson(json['image_url'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ContentToJson(Content instance) => <String, dynamic>{
  'type': instance.type,
  'text': instance.text,
  'image_url': instance.imageUrl,
};

ImageUrl _$ImageUrlFromJson(Map<String, dynamic> json) =>
    ImageUrl(url: json['url'] as String);

Map<String, dynamic> _$ImageUrlToJson(ImageUrl instance) => <String, dynamic>{
  'url': instance.url,
};

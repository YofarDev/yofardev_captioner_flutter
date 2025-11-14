// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptionRequest _$CaptionRequestFromJson(Map<String, dynamic> json) =>
    CaptionRequest(
      model: json['model'] as String,
      stream: json['stream'] as bool? ?? false,
      messages: (json['messages'] as List<dynamic>)
          .map((dynamic e) => Message.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CaptionRequestToJson(CaptionRequest instance) =>
    <String, dynamic>{
      'model': instance.model,
      'stream': instance.stream,
      'messages': instance.messages,
    };

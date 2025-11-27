// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'caption_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptionResponse _$CaptionResponseFromJson(Map<String, dynamic> json) =>
    CaptionResponse(
      choices: (json['choices'] as List<dynamic>)
          .map((e) => Choice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CaptionResponseToJson(CaptionResponse instance) =>
    <String, dynamic>{'choices': instance.choices};

Choice _$ChoiceFromJson(Map<String, dynamic> json) => Choice(
  message: ResponseMessage.fromJson(json['message'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ChoiceToJson(Choice instance) => <String, dynamic>{
  'message': instance.message,
};

ResponseMessage _$ResponseMessageFromJson(Map<String, dynamic> json) =>
    ResponseMessage(content: json['content'] as String);

Map<String, dynamic> _$ResponseMessageToJson(ResponseMessage instance) =>
    <String, dynamic>{'content': instance.content};

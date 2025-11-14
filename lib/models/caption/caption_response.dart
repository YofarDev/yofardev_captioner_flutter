import 'package:json_annotation/json_annotation.dart';

part 'caption_response.g.dart';

@JsonSerializable()
class CaptionResponse {
  final List<Choice> choices;

  CaptionResponse({required this.choices});

  factory CaptionResponse.fromJson(Map<String, dynamic> json) => _$CaptionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionResponseToJson(this);
}

@JsonSerializable()
class Choice {
  final ResponseMessage message;

  Choice({required this.message});

  factory Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);

  Map<String, dynamic> toJson() => _$ChoiceToJson(this);
}

@JsonSerializable()
class ResponseMessage {
  final String content;

  ResponseMessage({required this.content});

  factory ResponseMessage.fromJson(Map<String, dynamic> json) => _$ResponseMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ResponseMessageToJson(this);
}

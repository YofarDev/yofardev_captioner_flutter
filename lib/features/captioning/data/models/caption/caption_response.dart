import 'package:json_annotation/json_annotation.dart';

part 'caption_response.g.dart';

@JsonSerializable()
class CaptionResponse {
  final List<Choice> choices;

  CaptionResponse({required this.choices});

  factory CaptionResponse.fromJson(Map<String, dynamic> json) =>
      _$CaptionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionResponseToJson(this);
}

@JsonSerializable()
class Choice {
  final ResponseMessage message;

  /// Why the model stopped generating. Standard values:
  ///   `stop` — natural completion.
  ///   `length` — hit `max_tokens`, output is **truncated**.
  ///   `content_filter` — blocked by safety filter.
  /// Null when the provider omits the field.
  @JsonKey(name: 'finish_reason')
  final String? finishReason;

  Choice({required this.message, this.finishReason});

  factory Choice.fromJson(Map<String, dynamic> json) => _$ChoiceFromJson(json);

  Map<String, dynamic> toJson() => _$ChoiceToJson(this);
}

@JsonSerializable()
class ResponseMessage {
  final String content;

  ResponseMessage({required this.content});

  factory ResponseMessage.fromJson(Map<String, dynamic> json) =>
      _$ResponseMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ResponseMessageToJson(this);
}

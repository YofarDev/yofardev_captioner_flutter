import 'package:json_annotation/json_annotation.dart';
import 'message.dart';

part 'caption_request.g.dart';

@JsonSerializable()
class CaptionRequest {
  final String model;
  final bool stream;
  final List<Message> messages;

  CaptionRequest({
    required this.model,
    this.stream = false,
    required this.messages,
  });

  factory CaptionRequest.fromJson(Map<String, dynamic> json) =>
      _$CaptionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionRequestToJson(this);
}

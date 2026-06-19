import 'package:json_annotation/json_annotation.dart';
import 'message.dart';

part 'caption_request.g.dart';

@JsonSerializable()
class CaptionRequest {
  final String model;
  final bool stream;
  final List<Message> messages;

  /// Maximum number of tokens the model may generate. Null omits the field
  /// (provider default). The structured-captioning JSON is long, so callers
  /// that emit the full deconstruction should pass a high floor (e.g. 4096)
  /// to avoid silent truncation → malformed JSON.
  @JsonKey(includeIfNull: false, name: 'max_tokens')
  final int? maxTokens;

  CaptionRequest({
    required this.model,
    this.stream = false,
    required this.messages,
    this.maxTokens,
  });

  factory CaptionRequest.fromJson(Map<String, dynamic> json) =>
      _$CaptionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionRequestToJson(this);
}

import 'package:json_annotation/json_annotation.dart';
import 'content.dart';

part 'message.g.dart';

@JsonSerializable()
class Message {
  final String role;
  final List<Content> content;

  Message({required this.role, required this.content});

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  role: json['role'] as String,
  content: (json['content'] as List<dynamic>)
      .map((e) => Content.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'role': instance.role,
  'content': instance.content,
};

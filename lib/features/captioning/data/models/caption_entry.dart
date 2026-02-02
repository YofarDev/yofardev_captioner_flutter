import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'caption_entry.g.dart';

@JsonSerializable()
class CaptionEntry extends Equatable {
  final String text;
  final String? model;
  final DateTime? timestamp;
  final bool isEdited;

  const CaptionEntry({
    required this.text,
    this.model,
    this.timestamp,
    this.isEdited = false,
  });

  factory CaptionEntry.fromJson(Map<String, dynamic> json) =>
      _$CaptionEntryFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionEntryToJson(this);

  CaptionEntry copyWith({
    String? text,
    String? model,
    DateTime? timestamp,
    bool? isEdited,
  }) {
    return CaptionEntry(
      text: text ?? this.text,
      model: model ?? this.model,
      timestamp: timestamp ?? this.timestamp,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  @override
  List<Object?> get props => <Object?>[text, model, timestamp, isEdited];
}

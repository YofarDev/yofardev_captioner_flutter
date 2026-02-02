import 'package:json_annotation/json_annotation.dart';

import 'caption_entry.dart';

part 'caption_data.g.dart';

@JsonSerializable(explicitToJson: true)
class CaptionData {
  final String id;
  String filename;
  final Map<String, CaptionEntry> captions; // Changed from single fields
  final DateTime? lastModified;

  CaptionData({
    required this.id,
    required this.filename,
    required this.captions,
    this.lastModified,
  });

  factory CaptionData.fromJson(Map<String, dynamic> json) =>
      _$CaptionDataFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionDataToJson(this);
}

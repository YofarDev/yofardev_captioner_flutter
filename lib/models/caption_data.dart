import 'package:json_annotation/json_annotation.dart';

part 'caption_data.g.dart';

@JsonSerializable()
class CaptionData {
  final String id;
  String filename;
  String caption;
  String? captionModel;
  DateTime? captionTimestamp;
  DateTime? lastModified;

  CaptionData({
    required this.id,
    required this.filename,
    this.caption = '',
    this.captionModel,
    this.captionTimestamp,
    this.lastModified,
  });

  factory CaptionData.fromJson(Map<String, dynamic> json) =>
      _$CaptionDataFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionDataToJson(this);
}

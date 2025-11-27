import 'package:json_annotation/json_annotation.dart';

import 'caption_data.dart';

part 'caption_database.g.dart';

@JsonSerializable(explicitToJson: true)
class CaptionDatabase {
  List<CaptionData> images;

  CaptionDatabase({required this.images});

  factory CaptionDatabase.fromJson(Map<String, dynamic> json) =>
      _$CaptionDatabaseFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionDatabaseToJson(this);
}

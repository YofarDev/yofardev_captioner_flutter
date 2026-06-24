import 'package:json_annotation/json_annotation.dart';

import 'caption_data.dart';

part 'caption_database.g.dart';

@JsonSerializable(explicitToJson: true)
class CaptionDatabase {
  final int version;
  final List<String> categories;
  @JsonKey(defaultValue: <String, String>{})
  final Map<String, String> categoryFormats;
  final String? activeCategory;
  final List<CaptionData> images;

  CaptionDatabase({
    this.version = 4,
    required this.categories,
    this.categoryFormats = const <String, String>{},
    this.activeCategory,
    required this.images,
  });

  factory CaptionDatabase.fromJson(Map<String, dynamic> json) =>
      _$CaptionDatabaseFromJson(json);

  Map<String, dynamic> toJson() => _$CaptionDatabaseToJson(this);
}

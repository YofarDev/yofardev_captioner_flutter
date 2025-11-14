import 'package:json_annotation/json_annotation.dart';

part 'content.g.dart';

@JsonSerializable()
class Content {
  final String type;
  final String? text;
  @JsonKey(name: 'image_url')
  final ImageUrl? imageUrl;

  Content({required this.type, this.text, this.imageUrl});

  factory Content.fromJson(Map<String, dynamic> json) => _$ContentFromJson(json);

  Map<String, dynamic> toJson() => _$ContentToJson(this);
}

@JsonSerializable()
class ImageUrl {
  final String url;

  ImageUrl({required this.url});

  factory ImageUrl.fromJson(Map<String, dynamic> json) => _$ImageUrlFromJson(json);

  Map<String, dynamic> toJson() => _$ImageUrlToJson(this);
}

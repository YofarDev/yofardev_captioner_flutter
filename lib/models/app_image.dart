import 'dart:io';

import 'package:equatable/equatable.dart';

class AppImage extends Equatable {
  final File image;
  final String caption;
  final int width;
  final int height;
  final int size;

  const AppImage({
    required this.image,
    required this.caption,
    this.width = -1,
    this.height = -1,
    this.size = -1,
  });

  @override
  List<Object?> get props => <Object?>[image, caption, width, height, size];

  AppImage copyWith({
    File? image,
    String? caption,
    int? width,
    int? height,
    int? size,
  }) {
    return AppImage(
      image: image ?? this.image,
      caption: caption ?? this.caption,
      width: width ?? this.width,
      height: height ?? this.height,
      size: size ?? this.size,
    );
  }
}

import 'dart:io';
import 'package:equatable/equatable.dart';

class AppImage extends Equatable {
  final String id;
  final File image;
  final String caption;
  final int width;
  final int height;
  final int size;
  final String? error;
  const AppImage({
    required this.id,
    required this.image,
    required this.caption,
    this.width = -1,
    this.height = -1,
    this.size = -1,
    this.error,
  });

  double get aspectRatioAsDouble {
    if (width <= 0 || height <= 0) {
      return 0.0;
    }
    return width / height;
  }

  @override
  List<Object?> get props => <Object?>[
    image,
    caption,
    width,
    height,
    size,
    error,
  ];
  AppImage copyWith({
    String? id,
    File? image,
    String? caption,
    int? width,
    int? height,
    int? size,
    String? error,
  }) {
    return AppImage(
      id: id ?? this.id,
      image: image ?? this.image,
      caption: caption ?? this.caption,
      width: width ?? this.width,
      height: height ?? this.height,
      size: size ?? this.size,
      error: error ?? this.error,
    );
  }
}

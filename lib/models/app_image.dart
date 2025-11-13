import 'dart:io';

import 'package:equatable/equatable.dart';

class AppImage extends Equatable {
  final File image;
  final String caption;
  final int width;
  final int height;
  final int size;
  final String? error;

  const AppImage({
    required this.image,
    required this.caption,
    this.width = -1,
    this.height = -1,
    this.size = -1,
    this.error,
  });

  String get aspectRatio {
    if (width == -1 || height == -1 || height == 0) {
      return '...';
    }
    return (width / height).toStringAsFixed(2);
  }

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
    File? image,
    String? caption,
    int? width,
    int? height,
    int? size,
    String? error,
  }) {
    return AppImage(
      image: image ?? this.image,
      caption: caption ?? this.caption,
      width: width ?? this.width,
      height: height ?? this.height,
      size: size ?? this.size,
      error: error ?? this.error,
    );
  }
}

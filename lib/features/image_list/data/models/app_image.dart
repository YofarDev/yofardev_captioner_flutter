import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../../captioning/data/models/caption_entry.dart';

class AppImage extends Equatable {
  final String id;
  final File image;
  final Map<String, CaptionEntry> captions;
  final int width;
  final int height;
  final int size;
  final String? error;
  final bool isCaptionEdited;
  final String? captionModel;
  final DateTime? captionTimestamp;
  final DateTime? lastModified;

  const AppImage({
    required this.id,
    required this.image,
    required this.captions,
    this.width = -1,
    this.height = -1,
    this.size = -1,
    this.error,
    this.isCaptionEdited = false,
    this.captionModel,
    this.captionTimestamp,
    this.lastModified,
  });

  String get caption {
    // Return empty string if no captions or no active category
    if (captions.isEmpty) return '';
    return captions.values.first.text;
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
    captions,
    width,
    height,
    size,
    error,
    isCaptionEdited,
    captionModel,
    captionTimestamp,
    lastModified,
  ];
  AppImage copyWith({
    String? id,
    File? image,
    Map<String, CaptionEntry>? captions,
    int? width,
    int? height,
    int? size,
    String? error,
    bool? isCaptionEdited,
    String? captionModel,
    DateTime? captionTimestamp,
    DateTime? lastModified,
    bool clearError = false,
  }) {
    return AppImage(
      id: id ?? this.id,
      image: image ?? this.image,
      captions: captions ?? this.captions,
      width: width ?? this.width,
      height: height ?? this.height,
      size: size ?? this.size,
      error: clearError ? null : (error ?? this.error),
      isCaptionEdited: isCaptionEdited ?? this.isCaptionEdited,
      captionModel: captionModel ?? this.captionModel,
      captionTimestamp: captionTimestamp ?? this.captionTimestamp,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

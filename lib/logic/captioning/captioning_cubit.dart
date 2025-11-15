import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/app_image.dart';
import '../../models/caption_options.dart';
import '../../models/llm_config.dart';
import '../../repositories/captioning_repository.dart';
import '../images_list/image_list_cubit.dart';

part 'captioning_state.dart';

class CaptioningCubit extends Cubit<CaptioningState> {
  CaptioningCubit(this._imageListCubit) : super(const CaptioningState());

  final ImageListCubit _imageListCubit;
  final CaptioningRepository _captioningRepository = CaptioningRepository();

  Future<void> runCaptioner({
    required LlmConfig llm,
    required String prompt,
    required CaptionOptions option,
  }) async {
    emit(state.copyWith(status: CaptioningStatus.inProgress, progress: 0.0));

    List<AppImage> imagesToCaption = <AppImage>[];
    final List<AppImage> allImages = _imageListCubit.state.images;

    switch (option) {
      case CaptionOptions.current:
        imagesToCaption = <AppImage>[
          _imageListCubit.state.images[_imageListCubit.state.currentIndex]
        ];
      case CaptionOptions.missing:
        imagesToCaption =
            allImages.where((AppImage image) => image.caption.isEmpty).toList();
      case CaptionOptions.all:
        imagesToCaption = List<AppImage>.from(allImages);
    }

    final int totalImagesCount = imagesToCaption.length;
    if (totalImagesCount == 0) {
      emit(state.copyWith(status: CaptioningStatus.success, totalImages: 0));
      return;
    }
    int processedImagesCount = 0;
    final List<String> errors = <String>[];

    for (final AppImage image in imagesToCaption) {
      try {
        final AppImage updatedImage = await _captioningRepository.captionImage(
          llm,
          image,
          prompt,
        );
        _imageListCubit.updateImageByPath(
          imagePath: image.image.path,
          caption: updatedImage.caption,
        );
      } catch (e) {
        errors.add('Failed to caption ${image.image.path}: $e');
      }
      processedImagesCount++;
      emit(state.copyWith(
        progress: processedImagesCount / totalImagesCount,
        processedImages: processedImagesCount,
        totalImages: totalImagesCount,
      ));
    }

    if (errors.isNotEmpty) {
      emit(state.copyWith(
        status: CaptioningStatus.failure,
        error: errors.join('\n'),
        processedImages: totalImagesCount - errors.length,
      ));
    } else {
      emit(state.copyWith(
        status: CaptioningStatus.success,
        processedImages: totalImagesCount,
        totalImages: totalImagesCount,
      ));
    }
  }

  void clearErrors() {
    emit(state.copyWith(status: CaptioningStatus.initial));
  }
}

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../image_list/data/models/app_image.dart';
import '../../image_list/logic/image_list_cubit.dart';
import '../../llm_config/data/models/llm_config.dart';
import '../data/models/caption_options.dart';
import '../data/repositories/captioning_repository.dart';

part 'captioning_state.dart';

class CaptioningCubit extends Cubit<CaptioningState> {
  CaptioningCubit(
    this._imageListCubit, {
    CaptioningRepository? captioningRepository,
  }) : _captioningRepository = captioningRepository ?? CaptioningRepository(),
       super(const CaptioningState());

  final ImageListCubit _imageListCubit;
  final CaptioningRepository _captioningRepository;

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
          _imageListCubit.state.images[_imageListCubit.state.currentIndex],
        ];
      case CaptionOptions.missing:
        imagesToCaption = allImages
            .where((AppImage image) => image.caption.isEmpty)
            .toList();
      case CaptionOptions.all:
        imagesToCaption = allImages
            .where((AppImage image) => !image.isCaptionEdited)
            .toList();
    }

    final int totalImagesCount = imagesToCaption.length;
    emit(state.copyWith(totalImages: totalImagesCount, processedImages: 0));
    if (totalImagesCount == 0) {
      emit(state.copyWith(status: CaptioningStatus.success, totalImages: 0));
      return;
    }
    int processedImagesCount = 0;
    final List<String> errors = <String>[];

    for (final AppImage image in imagesToCaption) {
      if (processedImagesCount > 0 && llm.delay > 0) {
        await Future<void>.delayed(Duration(milliseconds: llm.delay));
      }

      emit(
        state.copyWith(
          currentlyCaptioningImage: image.image.path,
          setCurrentlyCaptioningImage: true,
        ),
      );
      try {
        final AppImage updatedImage = await _captioningRepository.captionImage(
          llm,
          image,
          prompt,
        );
        _imageListCubit.updateImage(image: updatedImage);
      } catch (e) {
        errors.add('Failed to caption ${image.image.path}: $e');
      }
      processedImagesCount++;
      emit(
        state.copyWith(
          progress: processedImagesCount / totalImagesCount,
          processedImages: processedImagesCount,
          totalImages: totalImagesCount,
          setCurrentlyCaptioningImage: true,
        ),
      );
    }

    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: CaptioningStatus.failure,
          error: errors.join('\n'),
          processedImages: totalImagesCount - errors.length,
          setCurrentlyCaptioningImage: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: CaptioningStatus.success,
          processedImages: totalImagesCount,
          totalImages: totalImagesCount,
          error: '',
          setCurrentlyCaptioningImage: true,
        ),
      );
    }
  }

  void clearErrors() {
    emit(state.copyWith(status: CaptioningStatus.initial));
  }
}

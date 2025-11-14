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

    final List<AppImage> images = _imageListCubit.state.images;
    final int totalImages = images.length;
    int processedImages = 0;

    for (int i = 0; i < totalImages; i++) {
      try {
        final AppImage image = images[i];
        final AppImage updatedImage = await _captioningRepository.captionImage(
          llm,
          image,
          prompt,
        );
        _imageListCubit.updateCaption(caption: updatedImage.caption);
        processedImages++;
        emit(state.copyWith(progress: processedImages / totalImages));
      } catch (e) {
        emit(
          state.copyWith(status: CaptioningStatus.failure, error: e.toString()),
        );
        return;
      }
    }

    emit(state.copyWith(status: CaptioningStatus.success));
  }

  void clearErrors() {
    emit(state.copyWith(status: CaptioningStatus.initial));
  }
}

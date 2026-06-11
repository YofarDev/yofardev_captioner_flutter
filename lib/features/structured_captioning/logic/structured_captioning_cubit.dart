import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/captioning/data/models/caption_entry.dart';
import '../../captioning/data/models/caption_options.dart';
import '../../image_list/data/models/app_image.dart';
import '../../image_list/logic/image_list_cubit.dart';
import '../../llm_config/data/models/llm_config.dart';
import '../data/models/ideogram_caption.dart';
import '../data/repositories/structured_caption_repository.dart';

part 'structured_captioning_state.dart';

class StructuredCaptioningCubit extends Cubit<StructuredCaptioningState> {
  StructuredCaptioningCubit(
    this._imageListCubit, {
    StructuredCaptionRepository? repository,
  }) : _repository = repository ?? StructuredCaptionRepository(),
       super(const StructuredCaptioningState());

  final ImageListCubit _imageListCubit;
  final StructuredCaptionRepository _repository;

  Completer<void>? _cancelCompleter;

  /// Runs the structured captioning pipeline on selected images.
  Future<void> runStructuredCaptioner({
    required LlmConfig llm,
    required CaptionOptions option,
  }) async {
    _cancelCompleter = Completer<void>();
    emit(
      state.copyWith(
        status: StructuredCaptioningStatus.inProgress,
        progress: 0.0,
        isCancelling: false,
        clearError: true,
      ),
    );

    List<AppImage> imagesToProcess = <AppImage>[];
    final List<AppImage> allImages = _imageListCubit.state.images;

    switch (option) {
      case CaptionOptions.current:
        final AppImage? currentImage = _imageListCubit.currentDisplayedImage;
        if (currentImage == null) {
          emit(
            state.copyWith(
              status: StructuredCaptioningStatus.failure,
              error: 'No image selected',
            ),
          );
          return;
        }
        imagesToProcess = <AppImage>[currentImage];
      case CaptionOptions.missing:
        final String category =
            _imageListCubit.state.activeCategory ?? 'default';
        imagesToProcess = allImages
            .where(
              (AppImage image) =>
                  (image.captions[category]?.text ?? '').isEmpty,
            )
            .toList();
      case CaptionOptions.all:
        imagesToProcess = allImages
            .where((AppImage image) => !image.isCaptionEdited)
            .toList();
    }

    final int total = imagesToProcess.length;
    emit(state.copyWith(totalImages: total, processedImages: 0));
    if (total == 0) {
      emit(
        state.copyWith(
          status: StructuredCaptioningStatus.success,
          totalImages: 0,
        ),
      );
      return;
    }

    int processed = 0;
    final List<String> errors = <String>[];

    for (final AppImage image in imagesToProcess) {
      // Check cancellation.
      if (_cancelCompleter?.isCompleted ?? false) {
        emit(
          state.copyWith(
            status: StructuredCaptioningStatus.initial,
            error: 'Structured captioning cancelled',
          ),
        );
        _cancelCompleter = null;
        return;
      }

      // Delay between calls.
      if (processed > 0 && llm.delay > 0) {
        await Future<void>.delayed(Duration(milliseconds: llm.delay));
      }

      emit(
        state.copyWith(
          currentlyProcessingImage: image.image.path,
          setCurrentlyProcessingImage: true,
        ),
      );

      try {
        final IdeogramCaption result = await _repository
            .generateStructuredCaption(
              llm,
              image.image,
              onProgress: _onStepProgress,
            );

        // Store JSON string as caption in active category.
        final String category =
            _imageListCubit.state.activeCategory ?? 'default';
        final AppImage updatedImage = image.copyWith(
          captions: <String, CaptionEntry>{
            ...image.captions,
            category: CaptionEntry(
              text: result.toJsonString(),
              model: llm.name,
              timestamp: DateTime.now(),
            ),
          },
          lastModified: DateTime.now(),
          clearError: true,
        );
        _imageListCubit.updateImage(image: updatedImage);
      } catch (e) {
        errors.add('Failed to caption ${image.image.path}: $e');
        final AppImage errorImage = image.copyWith(error: '$e');
        _imageListCubit.updateImage(image: errorImage);
      }

      processed++;
      emit(
        state.copyWith(
          progress: processed / total,
          processedImages: processed,
          totalImages: total,
          setCurrentlyProcessingImage: true,
        ),
      );
    }

    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: StructuredCaptioningStatus.failure,
          error: errors.join('\n'),
          processedImages: total - errors.length,
          setCurrentlyProcessingImage: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: StructuredCaptioningStatus.success,
          processedImages: total,
          totalImages: total,
          clearError: true,
          setCurrentlyProcessingImage: true,
        ),
      );
    }
    _cancelCompleter = null;
  }

  void _onStepProgress(String step) {
    final StructuredCaptionStep stepEnum = _mapStepToEnum(step);
    emit(state.copyWith(currentStep: stepEnum, stepLabel: step));
  }

  StructuredCaptionStep _mapStepToEnum(String step) {
    if (step.contains('palette') && step.contains('element')) {
      return StructuredCaptionStep.elementPalettes;
    }
    if (step.contains('palette')) {
      return StructuredCaptionStep.extractingPalette;
    }
    if (step.contains('VLM') || step.contains('analyzing')) {
      return StructuredCaptionStep.vlmAnalysis;
    }
    if (step.contains('SAM') || step.contains('detection')) {
      return StructuredCaptionStep.samDetection;
    }
    if (step.contains('Building') || step.contains('building')) {
      return StructuredCaptionStep.buildingCaption;
    }
    return StructuredCaptionStep.idle;
  }

  void cancelStructuredCaptioning() {
    _cancelCompleter?.complete();
    emit(state.copyWith(isCancelling: true));
  }

  void clearErrors() {
    emit(state.copyWith(status: StructuredCaptioningStatus.initial));
  }
}

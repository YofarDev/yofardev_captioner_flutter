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

  Completer<void>? _cancelCompleter;

  Future<void> runCaptioner({
    required LlmConfig llm,
    required String prompt,
    required CaptionOptions option,
    bool scopeToFiltered = false,
  }) async {
    // Reset or create cancel completer
    _cancelCompleter = Completer<void>();
    emit(
      state.copyWith(
        status: CaptioningStatus.inProgress,
        progress: 0.0,
        isCancelling: false,
      ),
    );

    List<AppImage> imagesToCaption = <AppImage>[];
    // Capture the base set ONCE: filtered list when scoped, otherwise everything.
    // Re-reading filteredImages mid-run would be unsafe if the search changes.
    final List<AppImage> baseImages = scopeToFiltered
        ? _imageListCubit.filteredImages
        : _imageListCubit.state.images;
    // Capture the active category ONCE at the start so switching category tabs
    // mid-run doesn't redirect later captions into a different category.
    final String category = _imageListCubit.state.activeCategory ?? 'default';

    switch (option) {
      case CaptionOptions.current:
        final AppImage? currentImage = _imageListCubit.currentDisplayedImage;
        if (currentImage == null) {
          emit(
            state.copyWith(
              status: CaptioningStatus.failure,
              error: 'No image selected',
            ),
          );
          return;
        }
        imagesToCaption = <AppImage>[currentImage];
      case CaptionOptions.missing:
        imagesToCaption = baseImages
            .where(
              (AppImage image) =>
                  (image.captions[category]?.text ?? '').isEmpty,
            )
            .toList();
      case CaptionOptions.all:
        // When scoped, force re-caption every filtered image (drop the
        // isCaptionEdited guard). Unscoped: preserve current skip-edited behavior.
        imagesToCaption = scopeToFiltered
            ? baseImages.toList()
            : baseImages
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
      // Check if cancelled
      if (_cancelCompleter?.isCompleted ?? false) {
        emit(
          state.copyWith(
            status: CaptioningStatus.initial,
            error: 'Captioning cancelled',
          ),
        );
        _cancelCompleter = null;
        return;
      }

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
        AppImage updatedImage = await _captioningRepository.captionImage(
          llm,
          image,
          prompt,
          category: category,
        );
        // Clear any previous errors on success
        updatedImage = updatedImage.copyWith(clearError: true);
        _imageListCubit.updateImage(image: updatedImage);
      } catch (e) {
        errors.add('Failed to caption ${image.image.path}: $e');
        // Store error in the image object
        final AppImage errorImage = image.copyWith(error: '$e');
        _imageListCubit.updateImage(image: errorImage);
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
    // Clear the cancel completer when done
    _cancelCompleter = null;
  }

  /// Asks the LLM to rewrite the current image's active caption (text-only,
  /// no image sent) given free-form [instructions]. Operates on the currently
  /// displayed image only. Errors propagate to the caller for UX handling.
  Future<void> rewriteCaption({
    required LlmConfig llm,
    required String instructions,
  }) async {
    final AppImage? currentImage = _imageListCubit.currentDisplayedImage;
    if (currentImage == null) {
      throw Exception('No image selected');
    }
    final String category = _imageListCubit.state.activeCategory ?? 'default';
    final AppImage updatedImage = await _captioningRepository.rewriteCaption(
      llm,
      currentImage,
      instructions,
      category: category,
    );
    _imageListCubit.updateImage(image: updatedImage.copyWith(clearError: true));
  }

  void cancelCaptioning() {
    _cancelCompleter?.complete();
    emit(state.copyWith(isCancelling: true));
  }

  void clearErrors() {
    emit(state.copyWith(status: CaptioningStatus.initial));
  }
}

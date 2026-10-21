import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/utils/cancel_token.dart';
import '../../../caption_session/caption_session.dart';
import '../../domain/models/caption_options.dart';
import '../../domain/repositories/captioning_repository.dart';

part 'captioning_state.dart';

class CaptioningCubit extends Cubit<CaptioningState> {
  CaptioningCubit(
    this._session, {
    required ICaptioningRepository captioningRepository,
  }) : _captioningRepository = captioningRepository,
       super(const CaptioningState());

  final CaptionSessionService _session;
  final ICaptioningRepository _captioningRepository;

  /// Aborts the in-flight operation (kills the local subprocess to free
  /// VRAM) AND gates the image loop. null when no run is active.
  CancelToken? _cancelToken;

  /// Cancels any in-flight run so a closing tab stops LLM spend immediately.
  /// The cancel token makes the awaited repository call throw
  /// [CancellationException]; the loop guards then stop all emissions.
  @override
  Future<void> close() {
    _cancelToken?.cancel();
    return super.close();
  }

  Future<void> runCaptioner({
    required LlmConfig llm,
    required String prompt,
    required CaptionOptions option,
    bool scopeToFiltered = false,
    String? jsonContextCategory,
  }) async {
    // Reset or create cancel token.
    _cancelToken = CancelToken();
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
        ? _session.current.filteredImages
        : _session.state.images;
    // Capture the active category ONCE at the start so switching category tabs
    // mid-run doesn't redirect later captions into a different category.
    final String category = _session.state.activeCategory ?? 'default';

    switch (option) {
      case CaptionOptions.current:
        final AppImage? currentImage = _session.current.currentDisplayedImage;
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

    // Broadcast the displayed image's guidance to every image in the run so a
    // single guidance entry covers a whole filtered Run-All instead of only
    // the image it was keyed to. For the "current" option the source IS the
    // processed image, so behavior there is unchanged.
    final AppImage? guidanceSource = _session.current.currentDisplayedImage;
    final String runGuidance = guidanceSource == null
        ? ''
        : _session.guidanceFor(guidanceSource.image.path);

    for (final AppImage image in imagesToCaption) {
      if (isClosed) return;
      // Check if cancelled
      if (_cancelToken?.isCancelled ?? false) {
        _cancelToken = null;
        if (isClosed) return;
        emit(
          state.copyWith(
            status: CaptioningStatus.initial,
            error: 'Captioning cancelled',
          ),
        );
        return;
      }

      if (processedImagesCount > 0 && llm.delay > 0) {
        // Race the inter-image delay against cancellation so a stop request
        // during the wait is honored immediately rather than after the delay.
        await Future.any<void>(<Future<void>>[
          Future<void>.delayed(Duration(milliseconds: llm.delay)),
          if (_cancelToken != null) _cancelToken!.onCancel,
        ]);
        if (_cancelToken?.isCancelled ?? false) {
          _cancelToken = null;
          if (isClosed) return;
          emit(
            state.copyWith(
              status: CaptioningStatus.initial,
              error: 'Captioning cancelled',
            ),
          );
          return;
        }
      }

      emit(
        state.copyWith(
          currentlyCaptioningImage: image.image.path,
          setCurrentlyCaptioningImage: true,
        ),
      );
      try {
        final String jsonContext = jsonContextCategory == null
            ? ''
            : (image.captions[jsonContextCategory]?.text ?? '');
        // Per-image guidance: appended (not replacing) the user prompt so it
        // composes with both the settings prompt and any JSON reference. In a
        // batch run this is the displayed image's guidance broadcast to all.
        final String guidance = runGuidance;
        final String guidanceBlock = guidance.isEmpty
            ? ''
            : '\n\nPer-image guidance (authoritative):\n$guidance';
        final String effectivePrompt = jsonContext.isEmpty
            ? '$prompt$guidanceBlock'
            : '$prompt\n\n'
                  'Existing structured analysis of this image (JSON), use as reference:\n'
                  '$jsonContext$guidanceBlock';
        final Either<Failure, AppImage> result = await _captioningRepository
            .captionImage(
              llm,
              image,
              effectivePrompt,
              category: category,
              cancelToken: _cancelToken,
            );
        final AppImage? updatedImage = result.getRight().toNullable();
        if (updatedImage != null) {
          // Clear any previous errors on success
          _session.updateImage(image: updatedImage.copyWith(clearError: true));
        } else {
          final Failure f = result.getLeft().toNullable()!;
          final String message = failureMessage(f);
          errors.add('Failed to caption ${image.image.path}: $message');
          // Store error in the image object
          final AppImage errorImage = image.copyWith(error: message);
          _session.updateImage(image: errorImage);
        }
      } on CancellationException {
        // The in-flight op was aborted via stop — don't flag the image as
        // failed; just end the run cleanly.
        _cancelToken = null;
        if (isClosed) return;
        emit(
          state.copyWith(
            status: CaptioningStatus.initial,
            error: 'Captioning cancelled',
          ),
        );
        return;
      }
      processedImagesCount++;
      if (isClosed) return;
      emit(
        state.copyWith(
          progress: processedImagesCount / totalImagesCount,
          processedImages: processedImagesCount,
          totalImages: totalImagesCount,
          setCurrentlyCaptioningImage: true,
        ),
      );
    }

    if (isClosed) return;
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
          clearError: true,
          setCurrentlyCaptioningImage: true,
        ),
      );
    }
    // Clear the cancel token when done
    _cancelToken = null;
  }

  /// Asks the LLM to rewrite the current image's active caption (text-only,
  /// no image sent) given free-form [instructions]. Operates on the currently
  /// displayed image only. Returns a user-facing failure message, or null on
  /// success.
  Future<String?> rewriteCaption({
    required LlmConfig llm,
    required String instructions,
  }) async {
    final AppImage? currentImage = _session.current.currentDisplayedImage;
    if (currentImage == null) {
      return 'No image selected';
    }
    final String category = _session.state.activeCategory ?? 'default';
    final Either<Failure, AppImage> result = await _captioningRepository
        .rewriteCaption(llm, currentImage, instructions, category: category);
    if (isClosed) return 'Captioning cancelled';
    return result.fold<String?>(failureMessage, (AppImage updatedImage) {
      _session.updateImage(image: updatedImage.copyWith(clearError: true));
      return null;
    });
  }

  /// Batch text-only conversion: reads each image's caption from
  /// [sourceCategory], asks the LLM to transform it via [prompt], and writes
  /// the result into the active category. No image is sent. Useful for
  /// cross-format conversions such as JSON → natural language.
  // ponytail: the loop skeleton (cancel checks, delay race, progress emit,
  // error collection) is duplicated from runCaptioner. Extract a shared
  // _runBatch(targets, perImageTransform) if a third batch variant appears.
  Future<void> convertCaptionsBatch({
    required LlmConfig llm,
    required String sourceCategory,
    required String prompt,
    required CaptionOptions option,
    bool scopeToFiltered = false,
  }) async {
    _cancelToken = CancelToken();
    emit(
      state.copyWith(
        status: CaptioningStatus.inProgress,
        progress: 0.0,
        isCancelling: false,
      ),
    );

    final List<AppImage> baseImages = scopeToFiltered
        ? _session.current.filteredImages
        : _session.state.images;
    // Target is the active category; capture once so switching tabs mid-run
    // doesn't redirect later writes.
    final String targetCategory = _session.state.activeCategory ?? 'default';

    List<AppImage> targets = <AppImage>[];
    switch (option) {
      case CaptionOptions.current:
        final AppImage? currentImage = _session.current.currentDisplayedImage;
        if (currentImage == null) {
          emit(
            state.copyWith(
              status: CaptioningStatus.failure,
              error: 'No image selected',
            ),
          );
          return;
        }
        targets = <AppImage>[currentImage];
      case CaptionOptions.missing:
        targets = baseImages
            .where(
              (AppImage image) =>
                  (image.captions[targetCategory]?.text ?? '').isEmpty,
            )
            .toList();
      case CaptionOptions.all:
        targets = baseImages.toList();
    }
    // Drop anything with nothing to convert (empty source caption).
    targets = targets
        .where(
          (AppImage image) =>
              (image.captions[sourceCategory]?.text ?? '').trim().isNotEmpty,
        )
        .toList();

    final int totalImagesCount = targets.length;
    emit(state.copyWith(totalImages: totalImagesCount, processedImages: 0));
    if (totalImagesCount == 0) {
      emit(state.copyWith(status: CaptioningStatus.success, totalImages: 0));
      return;
    }

    int processedImagesCount = 0;
    final List<String> errors = <String>[];

    for (final AppImage image in targets) {
      if (isClosed) return;
      if (_cancelToken?.isCancelled ?? false) {
        _cancelToken = null;
        if (isClosed) return;
        emit(
          state.copyWith(
            status: CaptioningStatus.initial,
            error: 'Captioning cancelled',
          ),
        );
        return;
      }

      if (processedImagesCount > 0 && llm.delay > 0) {
        await Future.any<void>(<Future<void>>[
          Future<void>.delayed(Duration(milliseconds: llm.delay)),
          if (_cancelToken != null) _cancelToken!.onCancel,
        ]);
        if (_cancelToken?.isCancelled ?? false) {
          _cancelToken = null;
          if (isClosed) return;
          emit(
            state.copyWith(
              status: CaptioningStatus.initial,
              error: 'Captioning cancelled',
            ),
          );
          return;
        }
      }

      emit(
        state.copyWith(
          currentlyCaptioningImage: image.image.path,
          setCurrentlyCaptioningImage: true,
        ),
      );
      try {
        final Either<Failure, AppImage> result = await _captioningRepository
            .transformCaption(
              llm,
              image,
              sourceCategory,
              targetCategory,
              prompt,
            );
        final AppImage? updatedImage = result.getRight().toNullable();
        if (updatedImage != null) {
          _session.updateImage(image: updatedImage.copyWith(clearError: true));
        } else {
          final Failure f = result.getLeft().toNullable()!;
          final String message = failureMessage(f);
          errors.add('Failed to convert ${image.image.path}: $message');
          final AppImage errorImage = image.copyWith(error: message);
          _session.updateImage(image: errorImage);
        }
      } on CancellationException {
        _cancelToken = null;
        if (isClosed) return;
        emit(
          state.copyWith(
            status: CaptioningStatus.initial,
            error: 'Captioning cancelled',
          ),
        );
        return;
      }
      processedImagesCount++;
      if (isClosed) return;
      emit(
        state.copyWith(
          progress: processedImagesCount / totalImagesCount,
          processedImages: processedImagesCount,
          totalImages: totalImagesCount,
          setCurrentlyCaptioningImage: true,
        ),
      );
    }

    if (isClosed) return;
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
    _cancelToken = null;
  }

  void cancelCaptioning() {
    if (isClosed) return;
    _cancelToken?.cancel();
    emit(state.copyWith(isCancelling: true));
  }

  void clearErrors() {
    emit(state.copyWith(status: CaptioningStatus.initial, clearError: true));
  }
}

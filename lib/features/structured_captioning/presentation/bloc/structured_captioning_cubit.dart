import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/caption_entry.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/structured_batch_overrides.dart';
import '../../../../core/utils/cancel_token.dart';
import '../../../captioning/captioning.dart';
import '../../../image_list/image_list.dart';
import '../../data/repositories/structured_caption_repository.dart';

part 'structured_captioning_state.dart';

class StructuredCaptioningCubit extends Cubit<StructuredCaptioningState> {
  StructuredCaptioningCubit(
    this._session, {
    StructuredCaptionRepository? repository,
  }) : _repository = repository ?? StructuredCaptionRepository(),
       super(const StructuredCaptioningState());

  final CaptionSessionService _session;
  final StructuredCaptionRepository _repository;

  CancelToken? _cancelToken;

  /// Cancels the run's token so a closing tab stops the loop at the next
  /// iteration boundary. Cancelling aborts in-flight VLM HTTP calls and kills
  /// the SAM subprocess.
  @override
  Future<void> close() {
    _cancelToken?.cancel();
    return super.close();
  }

  /// Runs the structured captioning pipeline on selected images.
  Future<void> runStructuredCaptioner({
    required LlmConfig llm,
    required CaptionOptions option,
    StructuredBatchOverrides? overrides,
    bool debugMode = false,
    bool disableSam = false,
    bool vlmEmitsXyxy = true,
    bool multiStage = false,
    bool scopeToFiltered = false,
  }) async {
    _cancelToken = CancelToken();
    emit(
      state.copyWith(
        status: StructuredCaptioningStatus.inProgress,
        progress: 0.0,
        isCancelling: false,
        clearError: true,
      ),
    );

    List<AppImage> imagesToProcess = <AppImage>[];
    // Capture the base set ONCE: filtered list when scoped, otherwise everything.
    final List<AppImage> baseImages = scopeToFiltered
        ? _session.current.filteredImages
        : _session.state.images;

    switch (option) {
      case CaptionOptions.current:
        final AppImage? currentImage = _session.current.currentDisplayedImage;
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
        final String category = _session.state.activeCategory ?? 'default';
        imagesToProcess = baseImages.where((AppImage image) {
          final String text = image.captions[category]?.text ?? '';
          return text.isEmpty ||
              !IdeogramCaption.isIdeogramJson(text) ||
              IdeogramCaption.hasEmptyHighLevelDescription(text);
        }).toList();
      case CaptionOptions.all:
        // When scoped, force re-caption every filtered image (drop guard).
        imagesToProcess = scopeToFiltered
            ? baseImages.toList()
            : baseImages
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

    // Broadcast the displayed image's guidance to every image in the run so a
    // single guidance entry covers a whole filtered Run-All instead of only
    // the image it was keyed to. For the "current" option the source IS the
    // processed image, so behavior there is unchanged.
    final AppImage? guidanceSource = _session.current.currentDisplayedImage;
    final String runGuidance = guidanceSource == null
        ? ''
        : _session.guidanceFor(guidanceSource.image.path);

    for (final AppImage image in imagesToProcess) {
      if (isClosed) return;
      // Check cancellation.
      if (_cancelToken?.isCancelled ?? false) {
        _cancelToken = null;
        if (isClosed) return;
        emit(
          state.copyWith(
            status: StructuredCaptioningStatus.initial,
            error: 'Structured captioning cancelled',
          ),
        );
        return;
      }

      // Delay between calls, raced against cancellation so a stop request
      // during the wait is honored immediately rather than after the delay.
      if (processed > 0 && llm.delay > 0) {
        await Future.any<void>(<Future<void>>[
          Future<void>.delayed(Duration(milliseconds: llm.delay)),
          if (_cancelToken != null) _cancelToken!.onCancel,
        ]);
      }
      if (isClosed) return;

      emit(
        state.copyWith(
          currentlyProcessingImage: image.image.path,
          setCurrentlyProcessingImage: true,
        ),
      );

      try {
        final Either<Failure, IdeogramCaption> generateResult =
            await _repository.generateStructuredCaption(
              llm,
              image.image,
              onProgress: _onStepProgress,
              overrides: overrides,
              debugMode: debugMode,
              disableSam: disableSam,
              vlmEmitsXyxy: vlmEmitsXyxy,
              guidance: runGuidance,
              mode: multiStage
                  ? StructuredMode.multiStage
                  : StructuredMode.singleShot,
              cancelToken: _cancelToken,
            );
        final IdeogramCaption? result = generateResult.getRight().toNullable();
        if (result == null) {
          final Failure f = generateResult.getLeft().toNullable()!;
          final String message = failureMessage(f);
          errors.add('Failed to caption ${image.image.path}: $message');
          final AppImage errorImage = image.copyWith(error: message);
          _session.updateImage(image: errorImage);
          processed++;
          if (isClosed) return;
          emit(
            state.copyWith(
              processedImages: processed,
              totalImages: total,
              setCurrentlyProcessingImage: true,
            ),
          );
          continue;
        }

        // Store JSON string as caption in active category.
        final String category = _session.state.activeCategory ?? 'default';
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
        _session.updateImage(image: updatedImage);
      } on CancellationException {
        if (isClosed) return;
        _cancelToken = null;
        emit(
          state.copyWith(
            status: StructuredCaptioningStatus.initial,
            error: 'Structured captioning cancelled',
          ),
        );
        return;
      } catch (e) {
        if (isClosed) return;
        errors.add('Failed to caption ${image.image.path}: $e');
        final AppImage errorImage = image.copyWith(error: '$e');
        _session.updateImage(image: errorImage);
      }

      processed++;
      if (isClosed) return;
      emit(
        state.copyWith(
          progress: processed / total,
          processedImages: processed,
          totalImages: total,
          setCurrentlyProcessingImage: true,
        ),
      );
    }

    if (isClosed) return;
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
    _cancelToken = null;
  }

  void _onStepProgress(String step) {
    if (isClosed) return;
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
    if (isClosed) return;
    _cancelToken?.cancel();
    emit(state.copyWith(isCancelling: true));
  }

  void clearErrors() {
    emit(state.copyWith(status: StructuredCaptioningStatus.initial));
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/app_image.dart';
import '../../../models/caption_options.dart';
import '../../../models/llm_config.dart';
import '../../../repositories/captioning_repository.dart';
import '../images_cubit.dart';

class CaptioningHelper {
  final CaptioningRepository _captioningRepository;
  CaptioningHelper(this._captioningRepository);
  Stream<ImagesState> runCaptioner({
    required LlmConfig llm,
    required String prompt,
    required CaptionOptions option,
    required ImagesState state,
  }) async* {
    yield state.copyWith(isCaptioning: true);
    try {
      switch (option) {
        case CaptionOptions.current:
          yield* _captionCurrentImage(llm, prompt, state);
        case CaptionOptions.missing:
          yield* _captionMissingImages(llm, prompt, state);
        case CaptionOptions.all:
          yield* _captionAllImages(llm, prompt, state);
      }
    } catch (e) {
      yield state.copyWith(isCaptioning: false, captioningError: e.toString());
      debugPrint(e.toString());
    }
  }

  Stream<ImagesState> _captionCurrentImage(
    LlmConfig llm,
    String prompt,
    ImagesState state,
  ) async* {
    final AppImage updatedImage = await _captioningRepository.captionImage(
      llm,
      state.images[state.currentIndex],
      prompt,
    );
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages[state.currentIndex] = updatedImage;
    yield state.copyWith(images: updatedImages, isCaptioning: false);
  }

  Stream<ImagesState> _captionMissingImages(
    LlmConfig llm,
    String prompt,
    ImagesState state,
  ) async* {
    final List<AppImage> imagesToCaption = state.images
        .where((AppImage image) => image.caption.isEmpty)
        .toList();
    int captionedCount = 0;
    yield state.copyWith(
      captioningProgress: '$captionedCount/${imagesToCaption.length}',
      totalImagesToCaption: imagesToCaption.length,
      imagesBeingProcessed: imagesToCaption
          .map((AppImage e) => e.image.path)
          .toList(),
    );
    try {
      await for (final AppImage image in _captioningRepository.captionMissing(
        List<AppImage>.from(state.images),
        llm,
        prompt,
      )) {
        captionedCount++;
        final int index = state.images.indexWhere(
          (AppImage element) => element.image.path == image.image.path,
        );
        final List<AppImage> updatedImages = List<AppImage>.from(state.images);
        updatedImages[index] = image;
        final List<String> imagesBeingProcessed = List<String>.from(
          state.imagesBeingProcessed,
        )..remove(image.image.path);
        yield state.copyWith(
          images: updatedImages,
          captioningProgress: '$captionedCount/${imagesToCaption.length}',
          imagesBeingProcessed: imagesBeingProcessed,
        );
      }
    } finally {
      yield state.copyWith(
        isCaptioning: false,
        imagesBeingProcessed: <String>[],
      );
    }
  }

  Stream<ImagesState> _captionAllImages(
    LlmConfig llm,
    String prompt,
    ImagesState state,
  ) async* {
    final List<AppImage> allImages = List<AppImage>.from(state.images);
    int captionedCount = 0;
    yield state.copyWith(
      isCaptioning: true,
      captioningProgress: '$captionedCount/${allImages.length}',
      totalImagesToCaption: allImages.length,
      imagesBeingProcessed: allImages
          .map((AppImage e) => e.image.path)
          .toList(),
    );
    try {
      await for (final AppImage image in _captioningRepository.captionAll(
        List<AppImage>.from(state.images),
        llm,
        prompt,
      )) {
        captionedCount++;
        final int index = state.images.indexWhere(
          (AppImage element) => element.image.path == image.image.path,
        );
        final List<AppImage> updatedImages = List<AppImage>.from(state.images);
        updatedImages[index] = image;
        final List<String> imagesBeingProcessed = List<String>.from(
          state.imagesBeingProcessed,
        )..remove(image.image.path);
        yield state.copyWith(
          images: updatedImages,
          captioningProgress: '$captionedCount/${allImages.length}',
          imagesBeingProcessed: imagesBeingProcessed,
        );
      }
    } finally {
      yield state.copyWith(
        isCaptioning: false,
        imagesBeingProcessed: <String>[],
      );
    }
  }
}

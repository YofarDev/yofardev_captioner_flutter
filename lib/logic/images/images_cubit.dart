import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../../models/app_image.dart';
import '../../models/caption_options.dart';
import '../../models/llm_config.dart';
import '../../repositories/captioning_repository.dart';
import '../../services/cache_service.dart';
import '../../utils/app_file_utils.dart';
import '../../utils/caption_utils.dart';
import '../../utils/image_utils.dart';

part 'images_state.dart';

/// A Cubit that manages the state of images within the application.
///
/// This includes handling image loading, sorting, captioning, and file operations.
class ImagesCubit extends Cubit<ImagesState> {
  /// Creates an [ImagesCubit] with an initial [ImagesState].
  ImagesCubit() : super(const ImagesState());

  final AppFileUtils _fileUtils = AppFileUtils();
  final CaptionUtils _captionUtils = CaptionUtils();
  final CaptioningRepository _captioningRepository = CaptioningRepository();
  final Map<int, TextEditingController> _controllers =
      <int, TextEditingController>{};

  /// Retrieves or creates a [TextEditingController] for a given image index.
  ///
  /// This controller is used to manage the caption text for the image at [index].
  TextEditingController getCaptionController(int index) {
    return _controllers.putIfAbsent(
      index,
      () => TextEditingController(text: state.images[index].caption),
    );
  }

  @override
  Future<void> close() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    return super.close();
  }

  /// Initializes the cubit by loading the previously saved folder path.
  ///
  /// If a path is found, it triggers [onFolderPicked] to load images from that path.
  void onInit() async {
    await CacheService.loadFolderPath().then((String? path) {
      if (path != null) {
        onFolderPicked(path);
        emit(state.copyWith(folderPath: path));
      }
    });
  }

  /// Handles the event when a new folder is picked.
  ///
  /// Loads images from the [folderPath], updates the window title,
  /// and emits a new state with the loaded images, sorted by name in ascending order.
  void onFolderPicked(String folderPath) async {
    windowManager.setTitle('Yofardev Captioner ➡️ "$folderPath"');
    final List<AppImage> images = await _fileUtils.onFolderPicked(folderPath);
    emit(
      state.copyWith(
        images: images,
        sortBy: SortBy.name,
        sortAscending: true,
        folderPath: folderPath,
      ),
    );
    _getImagesSizeSync();
  }

  /// Sorts the images based on the provided [sortBy] criteria and [sortAscending] order.
  ///
  /// Emits a new state with the sorted list of images.
  void onSortChanged(SortBy sortBy, bool sortAscending) {
    final List<AppImage> images = List<AppImage>.from(state.images);
    switch (sortBy) {
      case SortBy.name:
        images.sort(
          (AppImage a, AppImage b) => a.image.path.compareTo(b.image.path),
        );
      case SortBy.size:
        images.sort((AppImage a, AppImage b) => a.size.compareTo(b.size));
      case SortBy.caption:
        images.sort((AppImage a, AppImage b) => a.caption.compareTo(b.caption));
    }
    if (!sortAscending) {
      final List<AppImage> reversed = images.reversed.toList();
      images.clear();
      images.addAll(reversed);
    }
    emit(
      state.copyWith(
        images: images,
        sortBy: sortBy,
        sortAscending: sortAscending,
      ),
    );
  }

  /// Saves the provided [text] as a caption to the given [file].
  void onSaveCaptionPressed(File file, String text) {
    unawaited(file.writeAsString(text));
  }

  /// Selects an image at the given [index].
  ///
  /// Emits a new state with the [currentIndex] updated.
  void onImageSelected(int index) {
    emit(state.copyWith(currentIndex: index));
  }

  /// Asynchronously retrieves the sizes of all images in the current state.
  ///
  /// Emits a new state with the updated image list including their sizes.
  Future<void> _getImagesSizeSync() async {
    final List<AppImage> updatedImages = await ImageUtils.getImagesSize(
      state.images,
    );
    // If a new folder has been loaded while it was getting sizes for previous
    // folder, don't update state to not reload the previous images
    if (state.folderPath != p.dirname(updatedImages[0].image.path)) {
      return;
    }
    emit(state.copyWith(images: updatedImages));
  }

  /// Renames all image files in the currently selected folder to sequential numbers.
  ///
  /// After renaming, it reloads the folder to update the image list.
  void renameAllFiles() async {
    if (state.folderPath == null) {
      return;
    }
    await _fileUtils.renameFilesToNumbers(state.folderPath!);
    onFolderPicked(state.folderPath!);
  }

  /// Performs a search and replace operation on all image captions.
  ///
  /// Replaces all occurrences of [search] text with [replace] text in captions.
  /// Emits a new state with the updated image captions.
  void searchAndReplace(String search, String replace) {
    final List<AppImage> updatedImages = _captionUtils.searchAndReplace(
      search,
      replace,
      state.images,
    );
    emit(state.copyWith(images: updatedImages));
  }

  /// Counts the occurrences of a specific [search] string within all image captions.
  ///
  /// Emits a new state with the updated [occurrencesCount].
  void countOccurrences(String search) {
    final int count = _captionUtils.countOccurrences(search, state.images);
    emit(state.copyWith(occurrencesCount: count));
  }

  /// Runs the captioning process for images using the specified LLM configuration.
  ///
  /// [llm]: The LLM configuration to use for captioning.
  /// [prompt]: The prompt to use for generating captions.
  /// [option]: Specifies which images to caption ('this', 'missing', or 'all').
  Future<void> runCaptioner({
    required LlmConfig llm,
    required String prompt,
    required CaptionOptions option,
  }) async {
    emit(state.copyWith(isCaptioning: true));
    try {
      switch (option) {
        case CaptionOptions.current:
          final AppImage updatedImage = await _captioningRepository
              .captionImage(llm, state.images[state.currentIndex], prompt);
          final List<AppImage> updatedImages = List<AppImage>.from(
            state.images,
          );
          updatedImages[state.currentIndex] = updatedImage;
          emit(state.copyWith(images: updatedImages));
        case CaptionOptions.missing:
          final List<AppImage> imagesToCaption = state.images
              .where((AppImage image) => image.caption.isEmpty)
              .toList();
          int captionedCount = 0;
          emit(
            state.copyWith(
              captioningProgress: '$captionedCount/${imagesToCaption.length}',
            ),
          );
          try {
            await for (final List<AppImage> images
                in _captioningRepository.captionMissing(
                  List<AppImage>.from(state.images),
                  llm,
                  prompt,
                )) {
              captionedCount++;
              emit(
                state.copyWith(
                  images: images,
                  captioningProgress:
                      '$captionedCount/${imagesToCaption.length}',
                ),
              );
            }
          } finally {
            emit(state.copyWith(isCaptioning: false));
          }
        case CaptionOptions.all:
          final List<AppImage> allImages = List<AppImage>.from(state.images);
          int captionedCount = 0;
          emit(
            state.copyWith(
              isCaptioning: true,
              captioningProgress: '$captionedCount/${allImages.length}',
            ),
          );
          try {
            await for (final List<AppImage> images
                in _captioningRepository.captionAll(
                  List<AppImage>.from(state.images),
                  llm,
                  prompt,
                )) {
              captionedCount++;
              emit(
                state.copyWith(
                  images: images,
                  captioningProgress: '$captionedCount/${allImages.length}',
                ),
              );
            }
          } finally {
            emit(state.copyWith(isCaptioning: false));
          }
      }
    } catch (e) {
      emit(state.copyWith(isCaptioning: false));
      debugPrint(e.toString());
    }
  }

  /// Updates the caption for the currently selected image.
  ///
  /// [caption]: The new caption text.
  /// Emits a new state with the updated image caption and saves the caption to a file.
  void updateCaption({required String caption}) async {
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages[state.currentIndex] = state.images[state.currentIndex]
        .copyWith(caption: caption);
    emit(state.copyWith(images: updatedImages));
    await File(
      p.setExtension(state.images[state.currentIndex].image.path, '.txt'),
    ).writeAsString(caption);
  }

  /// Exports all images and their captions as an archive.
  ///
  /// Requires a [folderPath] to be set.
  Future<void> exportAsArchive() async {
    if (state.folderPath == null) {
      return;
    }
    await _fileUtils.exportAsArchive(state.folderPath!, state.images);
  }

  /// Removes an image from the list and deletes its associated files.
  ///
  /// [index]: The index of the image to remove.
  /// Emits a new state with the image removed and updates the [currentIndex] if necessary.
  void removeImage(int index) {
    final AppImage image = state.images[index];
    _fileUtils.removeImage(image);

    final List<AppImage> updatedImages = List<AppImage>.from(state.images)
      ..removeAt(index);

    int newCurrentIndex = state.currentIndex;
    if (index == newCurrentIndex) {
      if (updatedImages.isEmpty) {
        newCurrentIndex = 0;
      } else if (index >= updatedImages.length) {
        newCurrentIndex = updatedImages.length - 1;
      }
    }

    emit(state.copyWith(images: updatedImages, currentIndex: newCurrentIndex));
  }
}

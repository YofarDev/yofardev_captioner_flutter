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
import '../../utils/extensions.dart';
import '../../utils/image_utils.dart';
import 'helpers/captioning_helper.dart';
import 'helpers/image_operations_helper.dart';

part 'images_state.dart';

/// A Cubit that manages the state of images within the application.
///
/// This includes handling image loading, sorting, captioning, and file operations.
/// The logic is split into helper classes for better organization:
/// - [CaptioningHelper]: Handles all captioning-related logic.
/// - [ImageOperationsHelper]: Manages image operations like cropping and conversion.
class ImagesCubit extends Cubit<ImagesState> {
  /// Creates an [ImagesCubit] with an initial [ImagesState].
  ImagesCubit() : super(const ImagesState()) {
    _captioningHelper = CaptioningHelper(_captioningRepository);
    _imageOperationsHelper = ImageOperationsHelper();
  }
  final AppFileUtils _fileUtils = AppFileUtils();
  final CaptionUtils _captionUtils = CaptionUtils();
  final CaptioningRepository _captioningRepository = CaptioningRepository();
  late final CaptioningHelper _captioningHelper;
  late final ImageOperationsHelper _imageOperationsHelper;
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
    CacheService.saveFolderPath(folderPath);
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
  void onImageSelected(int index) async {
    emit(state.copyWith(currentIndex: index));
    if (!(await _checkAllFiles())) {
      onFolderPicked(state.folderPath!);
    }
  }

  Future<bool> _checkAllFiles() async {
    for (final AppImage image in state.images) {
      final bool exists = await image.image.exists();
      if (!exists) {
        return false;
      }
    }
    return true;
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

  void searchAndReplace(String search, String replace) {
    final List<AppImage> updatedImages = _captionUtils.searchAndReplace(
      search,
      replace,
      state.images,
    );
    emit(state.copyWith(images: updatedImages));
  }

  void countOccurrences(String search) {
    final int count = _captionUtils.countOccurrences(search, state.images);
    emit(state.copyWith(occurrencesCount: count));
  }

  Future<void> runCaptioner({
    required LlmConfig llm,
    required String prompt,
    required CaptionOptions option,
  }) async {
    await for (final ImagesState newState in _captioningHelper.runCaptioner(
      llm: llm,
      prompt: prompt,
      option: option,
      state: state,
    )) {
      emit(newState);
    }
  }

  void renameAllFiles() async {
    if (state.folderPath == null) {
      return;
    }
    await _imageOperationsHelper.renameAllFiles(state.folderPath!);
    onFolderPicked(state.folderPath!);
  }

  Future<void> exportAsArchive() async {
    if (state.folderPath == null) {
      return;
    }
    await _imageOperationsHelper.exportAsArchive(
      state.folderPath!,
      state.images,
    );
  }

  void removeImage(int index) {
    final ImagesState newState = _imageOperationsHelper.removeImage(
      index,
      state,
    );
    emit(newState);
  }

  void convertAllImages({required String format, required int quality}) async {
    await for (final ImagesState newState
        in _imageOperationsHelper.convertAllImages(
          format: format,
          quality: quality,
          state: state,
        )) {
      emit(newState);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    onFolderPicked(state.folderPath!);
  }

  Future<void> cropCurrentImage(BuildContext context) async {
    final ImagesState? newState =
        await _imageOperationsHelper.cropCurrentImage(
      context,
      state,
    );
    if (newState != null) {
      emit(newState);
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

  void clearErrors({int? index}) {
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    if (index != null) {
      updatedImages[index] = updatedImages[index].copyWith();
    } else {
      for (int i = 0; i < updatedImages.length; i++) {
        if (updatedImages[i].error != null) {
          updatedImages[i] = updatedImages[i].copyWith();
        }
      }
    }
    emit(state.copyWith(images: updatedImages));
  }

  Map<String, int> getAspectRatioCounts() {
    final Map<String, int> counts = <String, int>{};
    for (final AppImage image in state.images) {
      final String aspectRatio = image.aspectRatio;
      counts[aspectRatio] = (counts[aspectRatio] ?? 0) + 1;
    }
    return counts;
  }
}

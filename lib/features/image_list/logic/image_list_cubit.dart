import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../data/models/app_image.dart';
import '../../../captioning/data/models/caption_data.dart';
import '../../../captioning/data/models/caption_database.dart';
import '../../../core/services/cache_service.dart';
import '../data/repositories/app_file_utils.dart';
import '../../../core/utils/extensions.dart';
import '../../../utils/image_utils.dart';

part 'image_list_state.dart';

class ImageListCubit extends Cubit<ImageListState> {
  ImageListCubit({AppFileUtils? fileUtils})
    : _fileUtils = fileUtils ?? AppFileUtils(),
      super(const ImageListState());

  final AppFileUtils _fileUtils;

  void onInit() async {
    await CacheService.loadFolderPath().then((String? path) {
      if (path != null) {
        onFolderPicked(path);
        emit(state.copyWith(folderPath: path));
      }
    });
  }

  Future<void> onFolderPicked(String folderPath, {bool force = false}) async {
    if (folderPath == state.folderPath && !force) {
      return;
    }

    emit(state.copyWith(
      images: <AppImage>[],
      currentIndex: 0,
      folderPath: folderPath,
      occurrencesCount: 0,
      occurrenceFileNames: <String>[],
    ));

    windowManager.setTitle('Yofardev Captioner ➡️ "$folderPath"');
    CacheService.saveFolderPath(folderPath);

    final List<AppImage> images = await _fileUtils.onFolderPicked(folderPath);

    if (state.folderPath != folderPath) {
      return;
    }

    emit(
      state.copyWith(
        images: images,
      ),
    );
    _getImagesSizeSync();
  }

  Future<void> onFileOpened(String filePath) async {
    final String folderPath = p.dirname(filePath);
    await onFolderPicked(folderPath);

    // Wait for the state to be updated with the new images
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final int index =
        state.images.indexWhere((AppImage img) => img.image.path == filePath);
    if (index != -1) {
      onImageSelected(index);
    }
  }

  void nextImage() {
    if (state.images.isEmpty) return;
    final int nextIndex = (state.currentIndex + 1) % state.images.length;
    onImageSelected(nextIndex);
  }

  void previousImage() {
    if (state.images.isEmpty) return;
    final int previousIndex =
        (state.currentIndex - 1 + state.images.length) % state.images.length;
    onImageSelected(previousIndex);
  }

  Future<void> saveChanges() async {
    final AppImage image = state.images[state.currentIndex];
    await _saveCaptionToFile(image);
    await _saveDb();
  }

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

  Future<void> _getImagesSizeSync() async {
    final List<AppImage> updatedImages = await ImageUtils.getImagesSize(
      state.images,
    );
    if (updatedImages.isEmpty) {
      return;
    }
    if (state.folderPath != p.dirname(updatedImages[0].image.path)) {
      return;
    }
    emit(state.copyWith(images: updatedImages));
  }

  Future<void> getSingleImageSize() async {
    final AppImage updatedImage = await ImageUtils.getSingleImageSize(
      state.images[state.currentIndex],
    );
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages[state.currentIndex] = updatedImage;
    emit(state.copyWith(images: updatedImages));
  }

  void searchAndReplace(String search, String replace) async {
    if (search.isEmpty) return;

    final List<AppImage> updatedImages = <AppImage>[];
    bool wasModified = false;
    for (final AppImage image in state.images) {
      if (image.caption.contains(search)) {
        wasModified = true;
        final String newCaption = image.caption.replaceAll(search, replace);
        updatedImages.add(
          image.copyWith(
            caption: newCaption,
            isCaptionEdited: true,
            lastModified: DateTime.now(),
          ),
        );
      } else {
        updatedImages.add(image);
      }
    }

    if (wasModified) {
      emit(state.copyWith(images: updatedImages));
      for (final AppImage image in updatedImages) {
        await _saveCaptionToFile(image);
      }
      await _saveDb();
    }
  }

  void countOccurrences(String search) {
    if (search.isEmpty) {
      emit(
        state.copyWith(occurrencesCount: 0, occurrenceFileNames: <String>[]),
      );
      return;
    }
    int count = 0;
    final List<String> fileNames = <String>[];
    for (final AppImage image in state.images) {
      final int matches = search.allMatches(image.caption).length;
      if (matches > 0) {
        count += matches;
        fileNames.add(p.basename(image.image.path));
      }
    }
    emit(
      state.copyWith(occurrencesCount: count, occurrenceFileNames: fileNames),
    );
  }

  void updateCaption({required String caption}) async {
    final AppImage originalImage = state.images[state.currentIndex];
    final AppImage updated = originalImage.copyWith(
      caption: caption,
      isCaptionEdited: true,
      lastModified: DateTime.now(),
      captionModel: caption.isEmpty ? '' : originalImage.captionModel,
      captionTimestamp: caption.isEmpty ? null : originalImage.captionTimestamp,
    );

    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages[state.currentIndex] = updated;

    emit(state.copyWith(images: updatedImages));
    await _saveCaptionToFile(updated);
    await _saveDb();
  }

  void updateImage({required AppImage image}) async {
    final int index = state.images.indexWhere((AppImage i) => i.id == image.id);
    if (index == -1) {
      return;
    }

    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages[index] = image;

    emit(state.copyWith(images: updatedImages));
    await _saveCaptionToFile(image);
    await _saveDb();
  }

  Future<void> _saveCaptionToFile(AppImage image) async {
    if (!image.isCaptionEdited) return;
    await _fileUtils.saveCaptionToFile(image);
  }

  Future<void> _saveDb() async {
    if (state.folderPath == null || state.folderPath!.isEmpty) return;
    final List<CaptionData> captionDataList = state.images
        .map<CaptionData>(
          (AppImage img) => CaptionData(
            id: img.id,
            filename: p.basename(img.image.path),
            captionModel: img.captionModel,
            captionTimestamp: img.captionTimestamp,
            lastModified: img.lastModified,
          ),
        )
        .toList();
    final CaptionDatabase db = CaptionDatabase(images: captionDataList);
    await _fileUtils.writeDb(state.folderPath!, db);
  }

  void removeImage(int index) async {
    final AppImage imageToRemove = state.images[index];
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages.removeAt(index);
    emit(state.copyWith(images: updatedImages, currentIndex: 0));
    await _saveDb();
    await _fileUtils.removeImage(imageToRemove.image);
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

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../../models/app_image.dart';
import '../../services/cache_service.dart';
import '../../utils/app_file_utils.dart';
import '../../utils/caption_utils.dart';
import '../../utils/extensions.dart';
import '../../utils/image_utils.dart';

part 'image_list_state.dart';

class ImageListCubit extends Cubit<ImageListState> {
  ImageListCubit({AppFileUtils? fileUtils})
    : _fileUtils = fileUtils ?? AppFileUtils(),
      super(const ImageListState());

  final AppFileUtils _fileUtils;
  final CaptionUtils _captionUtils = CaptionUtils();

  void onInit() async {
    await CacheService.loadFolderPath().then((String? path) {
      if (path != null) {
        onFolderPicked(path);
        emit(state.copyWith(folderPath: path));
      }
    });
  }

  Future<void> onFolderPicked(String folderPath) async {
    emit(state.copyWith(folderPath: "", images: <AppImage>[]));
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

  void searchAndReplace(String search, String replace) {
    final List<AppImage> updatedImages = _captionUtils.searchAndReplace(
      search,
      replace,
      state.images,
    );
    emit(state.copyWith(images: updatedImages));
  }

  void countOccurrences(String search) {
    final OccurrenceResult result = _captionUtils.countOccurrences(search, state.images);
    emit(state.copyWith(
      occurrencesCount: result.count,
      occurrenceFileNames: result.fileNames,
    ));
  }

  void updateCaption({required String caption}) async {
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages[state.currentIndex] = state.images[state.currentIndex]
        .copyWith(caption: caption);
    emit(state.copyWith(images: updatedImages));
    await File(
      p.setExtension(state.images[state.currentIndex].image.path, '.txt'),
    ).writeAsString(caption);
  }

  void updateImageByPath({
    required String imagePath,
    required String caption,
  }) async {
    final int index = state.images.indexWhere(
      (AppImage image) => image.image.path == imagePath,
    );
    if (index == -1) {
      return;
    }
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages[index] = state.images[index].copyWith(caption: caption);
    emit(state.copyWith(images: updatedImages));
    await File(p.setExtension(imagePath, '.txt')).writeAsString(caption);
  }

  void removeImage(int index) async {
    final AppImage imageToRemove = state.images[index];
    await _fileUtils.removeImage(imageToRemove);
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages.removeAt(index);
    emit(state.copyWith(images: updatedImages, currentIndex: 0));
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

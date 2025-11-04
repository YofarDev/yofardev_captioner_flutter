import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../models/app_image.dart';
import '../services/cache_service.dart';
import '../utils/files_utils.dart';
import '../utils/image_utils.dart';

part 'images_state.dart';

class ImagesCubit extends Cubit<ImagesState> {
  ImagesCubit() : super(const ImagesState());

  void onInit() async {
    await CacheService.loadFolderPath().then((String? path) {
      if (path != null) {
        onFolderPicked(path);
        emit(state.copyWith(folderPath: path));
      }
    });
  }

  void onFolderPicked(String folderPath) {
    final Directory dir = Directory(folderPath);
    final List<FileSystemEntity> files = dir.listSync();
    final List<AppImage> images = <AppImage>[];
    windowManager.setTitle("Yofardev Captioner - ${state.folderPath}");
    for (final FileSystemEntity file in files) {
      if (file is File) {
        final String extension = p.extension(file.path).toLowerCase();
        if (extension == '.jpg' ||
            extension == '.png' ||
            extension == '.jpeg' ||
            extension == '.webp') {
          final String captionPath = p.setExtension(file.path, '.txt');
          final String caption = File(captionPath).existsSync()
              ? File(captionPath).readAsStringSync()
              : '';
          images.add(
            AppImage(image: file, caption: caption, size: file.lengthSync()),
          );
        }
      }
    }
    images.sort(
      (AppImage a, AppImage b) => a.image.path.compareTo(b.image.path),
    );
    emit(
      state.copyWith(images: images, sortBy: SortBy.name, sortAscending: true),
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

  void onSaveCaptionPressed(File file, String text) {
    unawaited(file.writeAsString(text));
  }

  void onImageSelected(int index) {
    emit(state.copyWith(currentIndex: index));
  }

  Future<void> _getImagesSizeSync() async {
    final List<AppImage> updated = <AppImage>[];
    for (final AppImage image in state.images) {
      final Size size = await ImageUtils.getImageDimensions(image.image.path);
      updated.add(
        image.copyWith(
          width: size.width.toInt(),
          height: size.height.toInt(),
          size: image.image.lengthSync(),
        ),
      );
    }
    emit(state.copyWith(images: updated));
  }

  void renameAllFiles() async {
    if (state.folderPath == null) {
      return;
    }
    await FilesUtils().renameFilesToNumbers(state.folderPath!);
    onFolderPicked(state.folderPath!);
  }

  void searchAndReplace(String search, String replace) {
    final List<AppImage> updatedImages = <AppImage>[];
    for (final AppImage image in state.images) {
      final String captionPath = p.setExtension(image.image.path, '.txt');
      final File captionFile = File(captionPath);
      final String newCaption = image.caption.replaceAll(search, replace);
      captionFile.writeAsStringSync(newCaption);
      updatedImages.add(image.copyWith(caption: newCaption));
    }
    emit(state.copyWith(images: updatedImages));
  }

  void countOccurrences(String search) {
    if (search.isEmpty) {
      emit(state.copyWith(occurrencesCount: 0));
      return;
    }
    int count = 0;
    for (final AppImage image in state.images) {
      count += search.allMatches(image.caption).length;
    }
    emit(state.copyWith(occurrencesCount: count));
  }
}

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../../../../core/utils/extensions.dart';
import '../../../core/services/cache_service.dart';
import '../../../features/image_operations/data/utils/image_utils.dart';
import '../../captioning/data/models/caption_data.dart';
import '../../captioning/data/models/caption_database.dart';
import '../../captioning/data/models/caption_entry.dart';
import '../data/models/app_image.dart';
import '../data/repositories/app_file_utils.dart';

part 'image_list_state.dart';

class ImageListCubit extends Cubit<ImageListState> {
  static const MethodChannel _channel = MethodChannel(
    'dev.yofardev.io/open_file',
  );

  ImageListCubit({AppFileUtils? fileUtils})
    : _fileUtils = fileUtils ?? AppFileUtils(),
      super(const ImageListState());

  final AppFileUtils _fileUtils;

  /// Returns the filtered list of images based on the current search query.
  /// If no search query is active, returns all images.
  List<AppImage> get filteredImages {
    if (state.searchQuery.isEmpty) {
      return state.images;
    }

    final String query = state.caseSensitive
        ? state.searchQuery
        : state.searchQuery.toLowerCase();

    final String category = state.activeCategory ?? 'default';

    return state.images.where((AppImage image) {
      final String caption = image.captions[category]?.text ?? '';
      final String searchCaption = state.caseSensitive
          ? caption
          : caption.toLowerCase();
      return searchCaption.contains(query);
    }).toList();
  }

  /// Returns the list of images that should be displayed based on search state.
  List<AppImage> get displayedImages => filteredImages;

  /// Returns the currently displayed image based on the search state.
  AppImage? get currentDisplayedImage {
    final List<AppImage> displayed = displayedImages;
    if (displayed.isEmpty || state.currentIndex >= displayed.length) {
      return null;
    }
    return displayed[state.currentIndex];
  }

  Future<void> onInit({bool skipLoadLastSession = false}) async {
    if (skipLoadLastSession) {
      // Don't load the previous session folder if the app was launched with a file
      return;
    }

    final String? path = await CacheService.loadFolderPath();
    if (path != null) {
      // Small delay to ensure window is ready (fixes startup timing issue)
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await onFolderPicked(path).catchError((Object error) {
        // Clear state if folder no longer exists
        emit(const ImageListState());
      });
    }
  }

  Future<void> onFolderPicked(String folderPath, {bool force = false}) async {
    if (folderPath == state.folderPath && !force) {
      return;
    }

    emit(
      state.copyWith(
        images: <AppImage>[],
        currentIndex: 0,
        folderPath: folderPath,
        occurrencesCount: 0,
        occurrenceFileNames: <String>[],
        searchQuery: '',
        caseSensitive: false,
      ),
    );

    try {
      final String newTitle = 'Yofardev Captioner ➡️ "$folderPath"';

      // Use native method to set window title (works better on macOS)
      try {
        await _channel.invokeMethod('setWindowTitle', newTitle);
      } catch (e) {
        await windowManager.setTitle(newTitle);
      }

      CacheService.saveFolderPath(folderPath);

      final List<AppImage> images = await _fileUtils.onFolderPicked(folderPath);

      // Load database to get categories
      final CaptionDatabase db = await _fileUtils.readDb(folderPath);

      if (state.folderPath != folderPath) {
        return;
      }

      emit(state.copyWith(
        images: images,
        categories: db.categories,
        activeCategory: db.activeCategory ?? 'default',
      ));
    } catch (e) {
      // Clear state if folder couldn't be loaded (e.g., folder was removed)
      emit(const ImageListState());
      windowManager.setTitle('Yofardev Captioner');
      return;
    }

    // Get image sizes separately, don't fail if this fails
    try {
      await _getImagesSizeSync();
    } catch (_) {
      // Ignore errors from getting image sizes
    }
  }

  Future<void> onFileOpened(String filePath) async {
    final String folderPath = p.dirname(filePath);
    await onFolderPicked(folderPath);

    // Wait for the state to be updated with the new images
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final int index = state.images.indexWhere(
      (AppImage img) => img.image.path == filePath,
    );
    if (index != -1) {
      onImageSelected(index);
    }
  }

  void nextImage() {
    final List<AppImage> displayed = displayedImages;
    if (displayed.isEmpty) return;
    final int nextIndex = (state.currentIndex + 1) % displayed.length;
    emit(state.copyWith(currentIndex: nextIndex));
  }

  void previousImage() {
    final List<AppImage> displayed = displayedImages;
    if (displayed.isEmpty) return;
    final int previousIndex =
        (state.currentIndex - 1 + displayed.length) % displayed.length;
    emit(state.copyWith(currentIndex: previousIndex));
  }

  Future<void> saveChanges() async {
    await _saveDb();
  }

  void onSortChanged(SortBy sortBy, bool sortAscending) {
    final List<AppImage> images = List<AppImage>.from(state.images);
    final String category = state.activeCategory ?? 'default';

    switch (sortBy) {
      case SortBy.name:
        images.sort(
          (AppImage a, AppImage b) => a.image.path.compareTo(b.image.path),
        );
      case SortBy.size:
        images.sort((AppImage a, AppImage b) => b.size.compareTo(a.size));
      case SortBy.caption:
        images.sort(
          (AppImage a, AppImage b) {
            final String captionA = a.captions[category]?.text ?? '';
            final String captionB = b.captions[category]?.text ?? '';
            return _getWordCount(captionB).compareTo(_getWordCount(captionA));
          },
        );
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
    final AppImage? currentImage = currentDisplayedImage;
    if (currentImage == null) return;

    final AppImage updatedImage = await ImageUtils.getSingleImageSize(
      currentImage,
    );
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    final int index = updatedImages.indexWhere(
      (AppImage i) => i.id == currentImage.id,
    );
    if (index != -1) {
      updatedImages[index] = updatedImage;
    }
    emit(state.copyWith(images: updatedImages));
  }

  void searchAndReplace(String search, String replace) async {
    if (search.isEmpty) return;

    final String category = state.activeCategory ?? 'default';

    final List<AppImage> updatedImages = <AppImage>[];
    bool wasModified = false;
    for (final AppImage image in state.images) {
      final String caption = image.captions[category]?.text ?? '';
      if (caption.contains(search)) {
        wasModified = true;
        final String newCaption = caption.replaceAll(search, replace);
        final Map<String, CaptionEntry> updatedCaptions = Map<String, CaptionEntry>.from(image.captions);
        updatedCaptions[category] = CaptionEntry(
          text: newCaption,
          model: image.captions[category]?.model,
          timestamp: image.captions[category]?.timestamp,
          isEdited: true,
        );
        updatedImages.add(
          image.copyWith(
            captions: updatedCaptions,
            lastModified: DateTime.now(),
          ),
        );
      } else {
        updatedImages.add(image);
      }
    }

    if (wasModified) {
      emit(state.copyWith(images: updatedImages));
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

    final String category = state.activeCategory ?? 'default';

    int count = 0;
    final List<String> fileNames = <String>[];
    for (final AppImage image in state.images) {
      final String caption = image.captions[category]?.text ?? '';
      final int matches = search.allMatches(caption).length;
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
    final AppImage? originalImage = currentDisplayedImage;
    if (originalImage == null) return;

    final String category = state.activeCategory ?? 'default';
    final Map<String, CaptionEntry> updatedCaptions = Map<String, CaptionEntry>.from(originalImage.captions);

    // Get existing entry or create new one
    final CaptionEntry? existingEntry = updatedCaptions[category];
    updatedCaptions[category] = CaptionEntry(
      text: caption,
      model: caption.isEmpty ? null : existingEntry?.model,
      timestamp: caption.isEmpty ? null : existingEntry?.timestamp,
      isEdited: true,
    );

    final AppImage updated = originalImage.copyWith(
      captions: updatedCaptions,
      lastModified: DateTime.now(),
    );

    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    final int index = updatedImages.indexWhere(
      (AppImage i) => i.id == originalImage.id,
    );
    if (index != -1) {
      updatedImages[index] = updated;
    }

    emit(state.copyWith(images: updatedImages));
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
    await _saveDb();
  }

  Future<void> _saveDb() async {
    if (state.folderPath == null || state.folderPath!.isEmpty) return;

    final List<CaptionData> captionDataList = state.images
        .map<CaptionData>(
          (AppImage img) => CaptionData(
            id: img.id,
            filename: p.basename(img.image.path),
            captions: img.captions,
            lastModified: img.lastModified,
          ),
        )
        .toList();

    final CaptionDatabase db = CaptionDatabase(
      categories: state.categories,
      activeCategory: state.activeCategory,
      images: captionDataList,
    );

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

  int getTotalImagesSize() {
    int totalSize = 0;
    for (final AppImage image in state.images) {
      totalSize += image.size;
    }
    return totalSize;
  }

  /// Updates the search query and resets the current index to 0.
  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query, currentIndex: 0));
  }

  /// Toggles case sensitivity for search.
  void toggleCaseSensitive() {
    emit(state.copyWith(caseSensitive: !state.caseSensitive));
  }

  /// Clears the search query while preserving the current image selection.
  void clearSearch() {
    emit(state.copyWith(searchQuery: '', caseSensitive: false));
  }

  int _getWordCount(String text) {
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).length;
  }

  double getAverageWordsPerCaption() {
    final String category = state.activeCategory ?? 'default';

    final List<AppImage> imagesWithCaptions = state.images
        .where((AppImage image) =>
            (image.captions[category]?.text ?? '').isNotEmpty)
        .toList();

    if (imagesWithCaptions.isEmpty) {
      return 0.0;
    }

    int totalWords = 0;
    for (final AppImage image in imagesWithCaptions) {
      final String text = image.captions[category]?.text ?? '';
      totalWords += text.split(RegExp(r'\s+'))
          .where((String s) => s.isNotEmpty)
          .length;
    }

    return totalWords / imagesWithCaptions.length;
  }

  Future<void> duplicateImage() async {
    final AppImage? originalImage = currentDisplayedImage;
    if (originalImage == null) return;

    AppImage duplicatedImage = await _fileUtils.duplicateImage(originalImage);

    // Load the image dimensions for the duplicated image
    try {
      duplicatedImage = await ImageUtils.getSingleImageSize(duplicatedImage);
    } catch (_) {
      // If loading dimensions fails, continue without them
    }

    // Add the duplicated image to the list
    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages.add(duplicatedImage);

    // Sort images to maintain natural order
    updatedImages.sort(
      (AppImage a, AppImage b) =>
          _fileUtils.compareNatural(a.image.path, b.image.path),
    );

    // Find the index of the duplicated image
    final int newIndex = updatedImages.indexWhere(
      (AppImage img) => img.id == duplicatedImage.id,
    );

    emit(state.copyWith(images: updatedImages, currentIndex: newIndex));

    // Update the database with the new image
    await _saveDb();
  }

  void addCategory(String name) async {
    if (state.categories.contains(name)) {
      return; // Already exists
    }

    final List<String> updatedCategories = List<String>.from(state.categories)..add(name);
    emit(state.copyWith(categories: updatedCategories));

    await _saveDb();
  }

  void removeCategory(String name) async {
    if (state.categories.length <= 1) {
      return; // Must have at least one category
    }

    final List<String> updatedCategories = List<String>.from(state.categories)..remove(name);
    final String? newActiveCategory = state.activeCategory == name
        ? updatedCategories.first
        : state.activeCategory;

    emit(state.copyWith(
      categories: updatedCategories,
      activeCategory: newActiveCategory,
    ));

    await _saveDb();
  }

  void renameCategory(String oldName, String newName) async {
    if (state.categories.contains(newName)) {
      return; // Already exists
    }

    final List<String> updatedCategories = List<String>.from(state.categories);
    final int index = updatedCategories.indexOf(oldName);
    updatedCategories[index] = newName;

    // Update all images to rename the category key
    final List<AppImage> updatedImages = state.images.map<AppImage>((AppImage img) {
      final Map<String, CaptionEntry> newCaptions = Map<String, CaptionEntry>.from(img.captions);
      if (newCaptions.containsKey(oldName)) {
        newCaptions[newName] = newCaptions.remove(oldName)!;
      }
      return img.copyWith(captions: newCaptions);
    }).toList();

    final String? newActiveCategory = state.activeCategory == oldName
        ? newName
        : state.activeCategory;

    emit(state.copyWith(
      categories: updatedCategories,
      activeCategory: newActiveCategory,
      images: updatedImages,
    ));

    await _saveDb();
  }

  void setActiveCategory(String name) {
    if (!state.categories.contains(name)) {
      return;
    }
    emit(state.copyWith(activeCategory: name));
  }

  void reorderCategories(int oldIndex, int newIndex) async {
    final List<String> updatedCategories = List<String>.from(state.categories);
    int adjustedIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedIndex -= 1;
    }
    final String item = updatedCategories.removeAt(oldIndex);
    updatedCategories.insert(adjustedIndex, item);

    emit(state.copyWith(categories: updatedCategories));
    await _saveDb();
  }
}

import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/app_image.dart';
import '../../../core/models/ideogram_caption.dart';
import '../../../core/utils/extensions.dart';
import '../data/repositories/app_file_utils.dart';
import '../data/services/filter_parser_engine.dart';
import '../domain/services/caption_session_service.dart';
import '../domain/services/caption_session_snapshot.dart';
import 'image_cache_eviction.dart';
import 'image_list_state.dart';
export 'image_list_state.dart';

/// Thin adapter over [CaptionSessionService]: forwards commands to the
/// session and mirrors its snapshots into this cubit's [ImageListState]
/// stream. All behavior lives in the session; this class only adapts it to
/// BLoC plus the few Flutter/structured-caption concerns the domain service
/// must not own (image-cache eviction via the session's onBeforeFolderLoad
/// hook, caption-format detection for export).
class ImageListCubit extends Cubit<ImageListState> {
  ImageListCubit({
    AppFileUtils? fileUtils,
    CaptionFilterEngine? filterEngine,
    CaptionSessionService? session,
  }) : super(const ImageListState()) {
    _session = session ?? _createSession(fileUtils, filterEngine);
    _session.addListener(_onSnapshot);
  }

  late final CaptionSessionService _session;

  void _onSnapshot(CaptionSessionSnapshot snapshot) => emit(snapshot.state);

  CaptionSessionService _createSession(
    AppFileUtils? fileUtils,
    CaptionFilterEngine? filterEngine,
  ) {
    return CaptionSessionService(
      fileStore: fileUtils ?? AppFileUtils(),
      filterEngine: filterEngine ?? const FilterParserCaptionEngine(),
      onBeforeFolderLoad: () => evictImageCache(state.images),
    );
  }

  /// The session this adapter mirrors. Exposed so tab-scoped wiring can
  /// share one session across the cubits of a tab.
  CaptionSessionService get session => _session;

  @override
  void onChange(Change<ImageListState> change) {
    super.onChange(change);
    // State set directly on the cubit (tests seeding via emit) must reach
    // the session so it stays the single source of truth. Emissions driven
    // by the session are equal and therefore no-ops here.
    _session.adopt(change.nextState);
  }

  @override
  Future<void> close() {
    _session.removeListener(_onSnapshot);
    return super.close();
  }

  // ---------------------------------------------------------------------------
  // Derived views (delegate to the session's current snapshot)
  // ---------------------------------------------------------------------------

  /// Returns the filtered list of images based on the current search query.
  List<AppImage> get filteredImages => _session.current.filteredImages;

  /// Returns the list of images that should be displayed based on search
  /// state.
  List<AppImage> get displayedImages => _session.current.displayedImages;

  /// Returns the currently displayed image based on the search state.
  AppImage? get currentDisplayedImage => _session.current.currentDisplayedImage;

  // ---------------------------------------------------------------------------
  // Command forwarding
  // ---------------------------------------------------------------------------

  Future<void> onInit({String? folderPath}) async {
    await _session.onInit(folderPath: folderPath);
  }

  Future<void> onFolderPicked(String folderPath, {bool force = false}) =>
      _session.onFolderPicked(folderPath, force: force);

  Future<void> onFileOpened(String filePath) => _session.onFileOpened(filePath);

  void onImageSelected(String imageId) => _session.selectImage(imageId);

  void nextImage() => _session.nextImage();

  void previousImage() => _session.previousImage();

  void setGuidanceEnabled(bool enabled) => _session.setGuidanceEnabled(enabled);

  void setGuidance(String imagePath, String text) =>
      _session.setGuidance(imagePath, text);

  /// Returns the guidance string to inject for [imagePath], or '' when
  /// guidance is disabled or unset for that image. Centralizes the
  /// enabled-and-nonempty check so both captioning cubits stay in sync.
  String guidanceFor(String imagePath) {
    if (!state.guidanceEnabled) {
      return '';
    }
    return state.imageGuidance[imagePath] ?? '';
  }

  Future<void> saveChanges() => _session.saveChanges();

  void onSortChanged(SortBy sortBy, bool sortAscending) =>
      _session.onSortChanged(sortBy, sortAscending);

  Future<void> getSingleImageSize() => _session.getSingleImageSize();

  Future<void> searchAndReplace(String search, String replace) =>
      _session.searchAndReplace(search, replace);

  void countOccurrences(String search) => _session.countOccurrences(search);

  Future<void> updateCaption({required String caption}) =>
      _session.updateCaption(caption: caption);

  Future<void> updateImage({required AppImage image}) =>
      _session.updateImage(image: image);

  Future<void> removeImage(String imageId) => _session.removeImage(imageId);

  Future<void> duplicateImage() => _session.duplicateImage();

  Future<void> writeCaptionFiles() async {
    final String category = state.activeCategory ?? 'default';
    await _session.writeCaptionFiles(
      category: category,
      format: _effectiveFormat(state, category),
    );
  }

  Future<void> removeCaptionFiles() => _session.removeCaptionFiles();

  void updateSearchQuery(String query) => _session.updateSearchQuery(query);

  void toggleCaseSensitive() => _session.toggleCaseSensitive();

  void clearSearch() => _session.clearSearch();

  void addCategory(String name, {String format = 'txt'}) =>
      _session.addCategory(name, format: format);

  void removeCategory(String name) => _session.removeCategory(name);

  void renameCategory(String oldName, String newName) =>
      _session.renameCategory(oldName, newName);

  void setActiveCategory(String name) => _session.setActiveCategory(name);

  void reorderCategories(int oldIndex, int newIndex) =>
      _session.reorderCategories(oldIndex, newIndex);

  Future<void> addTag(String rawTag) => _session.addTag(rawTag);

  Future<void> removeTag(String tag) => _session.removeTag(tag);

  Future<void> setTags(List<String> rawTags) => _session.setTags(rawTags);

  // ---------------------------------------------------------------------------
  // Read-only helpers computed from state (no session round-trip needed)
  // ---------------------------------------------------------------------------

  /// Returns all unique tags across all images in the current folder.
  Set<String> getAllUniqueTags() {
    final Set<String> allTags = <String>{};
    for (final AppImage image in state.images) {
      allTags.addAll(image.tags);
    }
    return allTags;
  }

  /// Returns all unique medium values from structured captions across all
  /// images.
  Set<String> getAllUniqueMediums() {
    final Set<String> allMediums = <String>{};
    final String category = state.activeCategory ?? 'default';
    for (final AppImage image in state.images) {
      final String captionText = image.captions[category]?.text ?? '';
      if (captionText.trimLeft().startsWith('{')) {
        try {
          final IdeogramCaption parsed = IdeogramCaption.fromJson(
            jsonDecode(captionText) as Map<String, dynamic>,
          );
          if (parsed.styleDescription.medium.isNotEmpty) {
            allMediums.add(parsed.styleDescription.medium);
          }
        } catch (_) {
          // skip invalid JSON
        }
      }
    }
    return allMediums;
  }

  Map<String, int> getAspectRatioCounts() {
    final Map<String, int> counts = <String, int>{};
    for (final AppImage image in state.images) {
      final String aspectRatio = image.aspectRatio;
      counts[aspectRatio] = (counts[aspectRatio] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> getTagCounts() {
    final Map<String, int> counts = <String, int>{};
    for (final AppImage image in state.images) {
      for (final String tag in image.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
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

  double getAverageWordsPerCaption() {
    final String category = state.activeCategory ?? 'default';

    final List<AppImage> imagesWithCaptions = state.images
        .where(
          (AppImage image) => (image.captions[category]?.text ?? '').isNotEmpty,
        )
        .toList();

    if (imagesWithCaptions.isEmpty) {
      return 0.0;
    }

    int totalWords = 0;
    for (final AppImage image in imagesWithCaptions) {
      final String text = image.captions[category]?.text ?? '';
      totalWords += text
          .split(RegExp(r'\s+'))
          .where((String s) => s.isNotEmpty)
          .length;
    }

    return totalWords / imagesWithCaptions.length;
  }

  /// Returns the format for [category]: explicit if stored, else
  /// auto-detected from the first non-empty caption (Ideogram JSON → 'json',
  /// else 'txt').
  String _effectiveFormat(ImageListState state, String category) {
    final String? stored = state.categoryFormats[category];
    if (stored != null) {
      return stored;
    }
    for (final AppImage image in state.images) {
      final String text = image.captions[category]?.text ?? '';
      if (IdeogramCaption.isIdeogramJson(text)) {
        return 'json';
      }
      if (text.isNotEmpty) {
        return 'txt';
      }
    }
    return 'txt';
  }
}

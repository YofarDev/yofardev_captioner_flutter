import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/caption_data.dart';
import '../../../../core/models/caption_database.dart';
import '../../../../core/models/caption_entry.dart';
import '../models/image_list_state.dart';
import 'caption_session_snapshot.dart';

/// Port for every file/database operation the session needs. Implemented in
/// the data layer by `AppFileUtils` so the domain service stays free of
/// data-layer and Flutter dependencies.
abstract class CaptionFileStore {
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath);
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath);
  Future<void> writeDb(String folderPath, CaptionDatabase db);
  Future<void> removeImage(File imageFile);
  Future<void> writeCaptionFiles(
    String folderPath,
    List<AppImage> images,
    String category,
    String format,
  );
  Future<void> removeCaptionFiles(String folderPath, List<AppImage> images);
  Future<AppImage> duplicateImage(AppImage originalImage);
  int compareNatural(String a, String b);
  Future<List<AppImage>> getImagesSize(List<AppImage> images);
  Future<AppImage> getSingleImageSize(AppImage image);
}

/// Applies the active search query / structured filter to the image
/// collection. Implemented in the data layer on top of `FilterParser`.
abstract class CaptionFilterEngine {
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  });
}

/// Signature for the session's operational logging sink. The domain layer
/// must not import get_it/logging (architecture domain-purity rule), so
/// callers wire this to the app logger (e.g. `locator<Logger>()`).
typedef CaptionSessionLogger =
    void Function(String message, {Object? error, StackTrace? stackTrace});

/// DESIGN INTENT — the session service, not the cubit, owns [ImageListState].
/// The per-tab cubits are thin adapters over [current]/[state], which is what
/// lets the tab manager and the embedded Agent API observe and mutate live
/// session state without holding a cubit. UI-shaped fields (searchQuery,
/// sortBy, ...) living here is deliberate. Do not "fix" this in either
/// direction without replacing both observation paths first.
///
/// Owns the per-tab image session: collection, selection, categories,
/// filtering. One instance per tab, created by the tab manager BEFORE the
/// widget tree builds. Emits a [CaptionSessionSnapshot] on every state
/// change; the owning cubit (`ImageListCubit`) mirrors those snapshots into
/// its `ImageListState` stream.
class CaptionSessionService {
  CaptionSessionService({
    required CaptionFileStore fileStore,
    required CaptionFilterEngine filterEngine,
    void Function()? onBeforeFolderLoad,
    CaptionSessionLogger? logSevere,
    CaptionSessionLogger? logWarning,
  }) : _fileStore = fileStore,
       _filterEngine = filterEngine,
       _onBeforeFolderLoad = onBeforeFolderLoad,
       _logSevere = logSevere,
       _logWarning = logWarning;

  final CaptionFileStore _fileStore;
  final CaptionFilterEngine _filterEngine;

  /// Logging sinks, no-op when not wired (e.g. bare test instances).
  final CaptionSessionLogger? _logSevere;
  final CaptionSessionLogger? _logWarning;

  /// Called at the start of every folder (re)load so the owning cubit can
  /// evict stale Flutter image-cache entries (a Flutter concern the domain
  /// service must not touch itself).
  final void Function()? _onBeforeFolderLoad;

  /// Synchronous listeners: the owning cubit's `state` must be up to date
  /// immediately after a command returns (UI and tests rely on this).
  /// Deliberately NOT a broadcast StreamController — a controller delivers
  /// events in the zone it was created in, which would drag emissions out of
  /// the caller's zone and desynchronize widget listeners.
  final List<void Function(CaptionSessionSnapshot)> _listeners =
      <void Function(CaptionSessionSnapshot)>[];

  /// Lazily created view of the notifications for stream-based consumers.
  StreamController<CaptionSessionSnapshot>? _controller;

  ImageListState _state = const ImageListState();
  bool _disposed = false;

  Stream<CaptionSessionSnapshot> get snapshots {
    _controller ??= StreamController<CaptionSessionSnapshot>.broadcast();
    return _controller!.stream;
  }

  /// Registers a synchronous snapshot listener. Returns nothing; pair with
  /// [removeListener] on close.
  void addListener(void Function(CaptionSessionSnapshot) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(CaptionSessionSnapshot) listener) {
    _listeners.remove(listener);
  }

  CaptionSessionSnapshot get current => _snapshotOf(_state);

  /// The current session state. Read-mostly; the owning cubit mirrors this
  /// into its emitted `ImageListState`.
  ImageListState get state => _state;

  /// Replaces the session state AND emits a snapshot. For external mutators
  /// (e.g. image operations) that compute a full next state outside the
  /// session and need the UI (the owning cubit's listeners) to see it.
  void replaceState(ImageListState next) {
    _update(next);
  }

  /// Adopts [next] as the session state without emitting a snapshot.
  ///
  /// Called by the owning cubit when its state was set from the outside
  /// (e.g. tests seeding via `emit`) so the session stays the single source
  /// of truth. No-op when [next] equals the current state, which also makes
  /// session-driven emissions (the cubit emits back what it received) safe.
  void adopt(ImageListState next) {
    if (next != _state) {
      _state = next;
    }
  }

  /// Releases the snapshot stream. The session is owned by the tab manager;
  /// disposing it is the tab manager's job, never the cubit's.
  void dispose() {
    _disposed = true;
    _controller?.close();
    _listeners.clear();
  }

  void _update(ImageListState next) {
    if (_disposed || next == _state) {
      return;
    }
    _state = next;
    _notify();
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    final CaptionSessionSnapshot snapshot = _snapshotOf(_state);
    for (final void Function(CaptionSessionSnapshot) listener
        in List<void Function(CaptionSessionSnapshot)>.of(_listeners)) {
      listener(snapshot);
    }
    _controller?.add(snapshot);
  }

  CaptionSessionSnapshot _snapshotOf(ImageListState s) {
    final List<AppImage> filtered = filteredFor(s);
    return CaptionSessionSnapshot(
      state: s,
      filteredImages: filtered,
      displayedImages: filtered,
      currentDisplayedImage: _currentDisplayedFor(s, filtered),
    );
  }

  // ---------------------------------------------------------------------------
  // Derived views
  // ---------------------------------------------------------------------------

  /// Returns the filtered list of images for [s] based on its search query.
  List<AppImage> filteredFor(ImageListState s) => _filterEngine.filter(
    s.images,
    category: s.activeCategory ?? 'default',
    query: s.searchQuery,
    caseSensitive: s.caseSensitive,
  );

  int? _currentDisplayIndex(ImageListState s, List<AppImage> displayed) {
    final String? id = s.currentImageId;
    if (id == null) {
      return null;
    }
    for (int i = 0; i < displayed.length; i++) {
      if (displayed[i].id == id) {
        return i;
      }
    }
    return null;
  }

  AppImage? _currentDisplayedFor(ImageListState s, List<AppImage> displayed) {
    final int? index = _currentDisplayIndex(s, displayed);
    if (index == null) {
      if (displayed.isEmpty) {
        return null;
      }
      return displayed[0];
    }
    return displayed[index];
  }

  AppImage? get _currentDisplayedImage =>
      _currentDisplayedFor(_state, filteredFor(_state));

  // ---------------------------------------------------------------------------
  // Folder lifecycle
  // ---------------------------------------------------------------------------

  Future<void> onInit({String? folderPath}) async {
    if (folderPath == null) {
      return;
    }
    // TODO(refactor): replace this settle delay with a deterministic signal
    // (e.g. await the first snapshot after onFolderPicked) — do not change
    // behavior during the cubit-migration ratchet.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await onFolderPicked(folderPath).catchError((Object error) {
      _update(const ImageListState());
    });
  }

  Future<void> onFolderPicked(String folderPath, {bool force = false}) async {
    if (folderPath == _state.folderPath && !force) {
      return;
    }

    // Evict cached thumbnails so reload shows fresh images (see
    // [_onBeforeFolderLoad]).
    _onBeforeFolderLoad?.call();

    _update(
      _state.copyWith(
        images: <AppImage>[],
        folderPath: folderPath,
        occurrencesCount: 0,
        occurrenceFileNames: <String>[],
        searchQuery: '',
        caseSensitive: false,
      ),
    );

    try {
      final Either<
        Failure,
        ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
      >
      pickResult = await _fileStore.onFolderPicked(folderPath);
      final ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})?
      picked = pickResult.getRight().toNullable();
      if (picked == null) {
        // Folder load failed at the file boundary; clear the list like the
        // old catch path did and surface the failure to the UI.
        final Failure f = pickResult.getLeft().toNullable()!;
        _update(
          _state.copyWith(images: <AppImage>[], dbLoadError: failureMessage(f)),
        );
        return;
      }
      final List<AppImage> images = picked.images;
      final CaptionDatabase db = picked.db;
      final Failure? dbFailure = picked.dbFailure;

      if (_state.folderPath != folderPath) {
        return;
      }

      // Rebuild path-keyed guidance from the id-keyed db map so it matches
      // the in-memory key used by setGuidance/guidanceFor. Only images that
      // still exist on disk are re-keyed; stale entries drop naturally.
      final Map<String, String> guidanceByPath = <String, String>{};
      for (final AppImage img in images) {
        final String? g = db.imageGuidance[img.id];
        if (g != null && g.isNotEmpty) {
          guidanceByPath[img.image.path] = g;
        }
      }

      _update(
        _state.copyWith(
          images: images,
          categories: db.categories,
          categoryFormats: db.categoryFormats,
          activeCategory: db.activeCategory ?? 'default',
          currentImageId: images.isNotEmpty ? images[0].id : null,
          imageGuidance: guidanceByPath,
        ),
      );
      if (dbFailure != null) {
        // Corrupt db.json: images loaded with empty captions — surface the
        // non-blocking warning banner instead of failing the folder load.
        _update(_state.copyWith(dbLoadError: failureMessage(dbFailure)));
      } else {
        _update(_state.copyWith(clearDbLoadError: true));
      }
    } catch (e, s) {
      // Clear state if folder couldn't be loaded (e.g., folder was removed)
      _logSevere?.call(
        'onFolderPicked failed for $folderPath; resetting session state',
        error: e,
        stackTrace: s,
      );
      _update(const ImageListState());
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

    // TODO(refactor): replace this settle delay with a deterministic signal
    // (await the snapshot where the opened file is present) — do not change
    // behavior during the cubit-migration ratchet.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (_state.images.isEmpty) {
      return;
    }

    final int matchIndex = _state.images.indexWhere(
      (AppImage img) => img.image.path == filePath,
    );
    final AppImage target = matchIndex != -1
        ? _state.images[matchIndex]
        : _state.images[0];
    selectImage(target.id);
  }

  Future<void> _getImagesSizeSync() async {
    final List<AppImage> updatedImages = await _fileStore.getImagesSize(
      _state.images,
    );
    if (updatedImages.isEmpty) {
      return;
    }
    if (_state.folderPath != p.dirname(updatedImages[0].image.path)) {
      return;
    }
    _update(_state.copyWith(images: updatedImages));
  }

  // ---------------------------------------------------------------------------
  // Selection / navigation
  // ---------------------------------------------------------------------------

  void selectImage(String imageId) async {
    _update(_state.copyWith(currentImageId: imageId));
    // Cheap liveness probe: stat only the selected file instead of the whole
    // folder, so selecting an image in a large folder stays O(1).
    final int index = _state.images.indexWhere((AppImage i) => i.id == imageId);
    if (index == -1) {
      return;
    }
    if (!await _state.images[index].image.exists()) {
      final String? folder = _state.folderPath;
      if (folder != null) {
        await onFolderPicked(folder, force: true);
      }
    }
  }

  void nextImage() {
    final List<AppImage> displayed = filteredFor(_state);
    if (displayed.isEmpty) {
      return;
    }
    final int currentIdx = _currentDisplayIndex(_state, displayed) ?? 0;
    final int nextIndex = (currentIdx + 1) % displayed.length;
    _update(_state.copyWith(currentImageId: displayed[nextIndex].id));
  }

  void previousImage() {
    final List<AppImage> displayed = filteredFor(_state);
    if (displayed.isEmpty) {
      return;
    }
    final int currentIdx = _currentDisplayIndex(_state, displayed) ?? 0;
    final int previousIndex =
        (currentIdx - 1 + displayed.length) % displayed.length;
    _update(_state.copyWith(currentImageId: displayed[previousIndex].id));
  }

  // ---------------------------------------------------------------------------
  // Guidance
  // ---------------------------------------------------------------------------

  /// Toggles global guidance injection (applies to both captioning paths).
  void setGuidanceEnabled(bool enabled) {
    _update(_state.copyWith(guidanceEnabled: enabled));
  }

  /// Sets the per-image guidance string. An empty [text] clears the
  /// entry for [imagePath] so the map doesn't grow unbounded. Persisted to
  /// db.json on the next save (e.g. dialog close or any caption change).
  void setGuidance(String imagePath, String text) {
    final Map<String, String> next = Map<String, String>.from(
      _state.imageGuidance,
    );
    if (text.isEmpty) {
      next.remove(imagePath);
    } else {
      next[imagePath] = text;
    }
    _update(_state.copyWith(imageGuidance: next));
  }

  /// Returns the guidance string to inject for [imagePath], or '' when
  /// guidance is disabled or unset for that image. Centralizes the
  /// enabled-and-nonempty check so captioning consumers stay in sync.
  String guidanceFor(String imagePath) {
    if (!_state.guidanceEnabled) {
      return '';
    }
    return _state.imageGuidance[imagePath] ?? '';
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> saveChanges() async {
    await _saveDb();
  }

  Future<void> _saveDb() async {
    final String? folderPath = _state.folderPath;
    if (folderPath == null || folderPath.isEmpty) {
      return;
    }

    // Corrupt-db guard: while dbLoadError is set, captions were not loaded
    // from disk, so persisting the in-memory database would clobber the
    // (recoverable) db.json with empty captions. Edits stay in memory only;
    // the warning banner tells the user captions weren't loaded. Mirrors the
    // guard in AppFileUtils.updateDbForRename.
    if (_state.dbLoadError != null) {
      _logWarning?.call(
        'saveDb skipped: db.json is unreadable in $folderPath '
        '(${_state.dbLoadError}); keeping in-memory edits unsaved',
      );
      return;
    }

    final List<CaptionData> captionDataList = _state.images
        .map<CaptionData>(
          (AppImage img) => CaptionData(
            id: img.id,
            filename: p.basename(img.image.path),
            captions: img.captions,
            lastModified: img.lastModified,
            tags: img.tags,
          ),
        )
        .toList();

    // Translate path-keyed guidance to id-keyed so it survives folder moves.
    final Map<String, String> guidanceById = <String, String>{};
    for (final AppImage img in _state.images) {
      final String? g = _state.imageGuidance[img.image.path];
      if (g != null && g.isNotEmpty) {
        guidanceById[img.id] = g;
      }
    }

    final CaptionDatabase db = CaptionDatabase(
      categories: _state.categories,
      categoryFormats: _state.categoryFormats,
      activeCategory: _state.activeCategory,
      images: captionDataList,
      imageGuidance: guidanceById,
    );

    await _fileStore.writeDb(folderPath, db);
  }

  // ---------------------------------------------------------------------------
  // Sorting
  // ---------------------------------------------------------------------------

  void onSortChanged(SortBy sortBy, bool sortAscending) {
    final List<AppImage> images = List<AppImage>.from(_state.images);
    final String category = _state.activeCategory ?? 'default';

    switch (sortBy) {
      case SortBy.name:
        images.sort(
          (AppImage a, AppImage b) => a.image.path.compareTo(b.image.path),
        );
      case SortBy.size:
        images.sort((AppImage a, AppImage b) => b.size.compareTo(a.size));
      case SortBy.caption:
        images.sort((AppImage a, AppImage b) {
          final String captionA = a.captions[category]?.text ?? '';
          final String captionB = b.captions[category]?.text ?? '';
          return _getWordCount(captionB).compareTo(_getWordCount(captionA));
        });
    }
    if (!sortAscending) {
      final List<AppImage> reversed = images.reversed.toList();
      images.clear();
      images.addAll(reversed);
    }
    _update(
      _state.copyWith(
        images: images,
        sortBy: sortBy,
        sortAscending: sortAscending,
      ),
    );
  }

  int _getWordCount(String text) {
    if (text.isEmpty) {
      return 0;
    }
    return text.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).length;
  }

  // ---------------------------------------------------------------------------
  // Sizes
  // ---------------------------------------------------------------------------

  Future<void> getSingleImageSize() async {
    final AppImage? currentImage = _currentDisplayedImage;
    if (currentImage == null) {
      return;
    }

    final AppImage updatedImage = await _fileStore.getSingleImageSize(
      currentImage,
    );
    final List<AppImage> updatedImages = List<AppImage>.from(_state.images);
    final int index = updatedImages.indexWhere(
      (AppImage i) => i.id == currentImage.id,
    );
    if (index != -1) {
      updatedImages[index] = updatedImage;
    }
    _update(_state.copyWith(images: updatedImages));
  }

  // ---------------------------------------------------------------------------
  // Caption editing
  // ---------------------------------------------------------------------------

  Future<void> searchAndReplace(String search, String replace) async {
    if (search.isEmpty) {
      return;
    }

    final String category = _state.activeCategory ?? 'default';

    final List<AppImage> updatedImages = <AppImage>[];
    bool wasModified = false;
    for (final AppImage image in _state.images) {
      final String caption = image.captions[category]?.text ?? '';
      if (caption.contains(search)) {
        wasModified = true;
        final String newCaption = caption.replaceAll(search, replace);
        final Map<String, CaptionEntry> updatedCaptions =
            Map<String, CaptionEntry>.from(image.captions);
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
      _update(_state.copyWith(images: updatedImages));
      await _saveDb();
    }
  }

  void countOccurrences(String search) {
    if (search.isEmpty) {
      _update(
        _state.copyWith(occurrencesCount: 0, occurrenceFileNames: <String>[]),
      );
      return;
    }

    final String category = _state.activeCategory ?? 'default';

    int count = 0;
    final List<String> fileNames = <String>[];
    for (final AppImage image in _state.images) {
      final String caption = image.captions[category]?.text ?? '';
      final int matches = search.allMatches(caption).length;
      if (matches > 0) {
        count += matches;
        fileNames.add(p.basename(image.image.path));
      }
    }
    _update(
      _state.copyWith(occurrencesCount: count, occurrenceFileNames: fileNames),
    );
  }

  Future<void> updateCaption({required String caption}) async {
    final AppImage? originalImage = _currentDisplayedImage;
    if (originalImage == null) {
      return;
    }

    final String category = _state.activeCategory ?? 'default';
    final Map<String, CaptionEntry> updatedCaptions =
        Map<String, CaptionEntry>.from(originalImage.captions);

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

    final List<AppImage> updatedImages = List<AppImage>.from(_state.images);
    final int index = updatedImages.indexWhere(
      (AppImage i) => i.id == originalImage.id,
    );
    if (index != -1) {
      updatedImages[index] = updated;
    }

    _update(_state.copyWith(images: updatedImages));
    await _saveDb();
  }

  Future<void> updateImage({required AppImage image}) async {
    final int index = _state.images.indexWhere(
      (AppImage i) => i.id == image.id,
    );
    if (index == -1) {
      return;
    }

    final List<AppImage> updatedImages = List<AppImage>.from(_state.images);
    updatedImages[index] = image;

    _update(_state.copyWith(images: updatedImages));
    await _saveDb();
  }

  Future<void> removeImage(String imageId) async {
    final int index = _state.images.indexWhere((AppImage i) => i.id == imageId);
    if (index == -1) {
      return;
    }
    final AppImage imageToRemove = _state.images[index];
    final List<AppImage> updatedImages = List<AppImage>.from(_state.images);
    updatedImages.removeAt(index);
    final String? newCurrentId = updatedImages.isEmpty
        ? null
        : (index < updatedImages.length
              ? updatedImages[index].id
              : updatedImages.last.id);
    _update(
      _state.copyWith(images: updatedImages, currentImageId: newCurrentId),
    );
    await _saveDb();
    await _fileStore.removeImage(imageToRemove.image);
  }

  Future<void> duplicateImage() async {
    final AppImage? originalImage = _currentDisplayedImage;
    if (originalImage == null) {
      return;
    }

    AppImage duplicatedImage = await _fileStore.duplicateImage(originalImage);

    // Load the image dimensions for the duplicated image
    try {
      duplicatedImage = await _fileStore.getSingleImageSize(duplicatedImage);
    } catch (_) {
      // If loading dimensions fails, continue without them
    }

    // Add the duplicated image to the list
    final List<AppImage> updatedImages = List<AppImage>.from(_state.images);
    updatedImages.add(duplicatedImage);

    // Sort images to maintain natural order
    updatedImages.sort(
      (AppImage a, AppImage b) =>
          _fileStore.compareNatural(a.image.path, b.image.path),
    );

    _update(
      _state.copyWith(
        images: updatedImages,
        currentImageId: duplicatedImage.id,
      ),
    );

    // Update the database with the new image
    await _saveDb();
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Writes sidecar caption files. The caller (cubit adapter) computes the
  /// effective [format] because auto-detection parses structured captions,
  /// a cross-feature concern the domain service must not import.
  Future<void> writeCaptionFiles({
    required String category,
    required String format,
  }) async {
    final String? folderPath = _state.folderPath;
    if (folderPath == null) {
      return;
    }
    await _fileStore.writeCaptionFiles(
      folderPath,
      _state.images,
      category,
      format,
    );
  }

  Future<void> removeCaptionFiles() async {
    final String? folderPath = _state.folderPath;
    if (folderPath == null) {
      return;
    }
    await _fileStore.removeCaptionFiles(folderPath, _state.images);
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Updates the search query and resets the selection to the first image.
  void updateSearchQuery(String query) {
    final List<AppImage> displayed = _state.images;
    _update(
      _state.copyWith(
        searchQuery: query,
        currentImageId: displayed.isNotEmpty ? displayed[0].id : null,
      ),
    );
  }

  /// Toggles case sensitivity for search.
  void toggleCaseSensitive() {
    _update(_state.copyWith(caseSensitive: !_state.caseSensitive));
  }

  /// Clears the search query. Selection preserved automatically via ID
  /// tracking.
  void clearSearch() {
    _update(_state.copyWith(searchQuery: '', caseSensitive: false));
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  void addCategory(String name, {String format = 'txt'}) async {
    if (_state.categories.contains(name)) {
      return;
    }

    final List<String> updatedCategories = List<String>.from(_state.categories)
      ..add(name);
    final Map<String, String> updatedFormats = Map<String, String>.from(
      _state.categoryFormats,
    )..[name] = format;
    _update(
      _state.copyWith(
        categories: updatedCategories,
        categoryFormats: updatedFormats,
        activeCategory: name,
      ),
    );

    await _saveDb();
  }

  void removeCategory(String name) async {
    if (_state.categories.length <= 1) {
      return; // Must have at least one category
    }

    final List<String> updatedCategories = List<String>.from(_state.categories)
      ..remove(name);
    final Map<String, String> updatedFormats = Map<String, String>.from(
      _state.categoryFormats,
    )..remove(name);
    final String? newActiveCategory = _state.activeCategory == name
        ? updatedCategories.first
        : _state.activeCategory;

    _update(
      _state.copyWith(
        categories: updatedCategories,
        categoryFormats: updatedFormats,
        activeCategory: newActiveCategory,
      ),
    );

    await _saveDb();
  }

  void renameCategory(String oldName, String newName) async {
    if (_state.categories.contains(newName)) {
      return; // Already exists
    }

    final List<String> updatedCategories = List<String>.from(_state.categories);
    final int index = updatedCategories.indexOf(oldName);
    if (index == -1) {
      // Unknown source category (removed or renamed concurrently). A
      // RangeError here would escape this `void ... async` method unhandled.
      return;
    }
    updatedCategories[index] = newName;

    // Update all images to rename the category key
    final List<AppImage> updatedImages = _state.images.map<AppImage>((
      AppImage img,
    ) {
      final Map<String, CaptionEntry> newCaptions =
          Map<String, CaptionEntry>.from(img.captions);
      if (newCaptions.containsKey(oldName)) {
        newCaptions[newName] = newCaptions.remove(oldName)!;
      }
      return img.copyWith(captions: newCaptions);
    }).toList();

    final Map<String, String> updatedFormats = Map<String, String>.from(
      _state.categoryFormats,
    );
    if (updatedFormats.containsKey(oldName)) {
      updatedFormats[newName] = updatedFormats.remove(oldName)!;
    }

    final String? newActiveCategory = _state.activeCategory == oldName
        ? newName
        : _state.activeCategory;

    _update(
      _state.copyWith(
        categories: updatedCategories,
        categoryFormats: updatedFormats,
        activeCategory: newActiveCategory,
        images: updatedImages,
      ),
    );

    await _saveDb();
  }

  void setActiveCategory(String name) {
    if (!_state.categories.contains(name)) {
      return;
    }
    _update(_state.copyWith(activeCategory: name));
  }

  void reorderCategories(int oldIndex, int newIndex) async {
    final List<String> updatedCategories = List<String>.from(_state.categories);
    int adjustedIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedIndex -= 1;
    }
    final String item = updatedCategories.removeAt(oldIndex);
    updatedCategories.insert(adjustedIndex, item);

    _update(_state.copyWith(categories: updatedCategories));
    await _saveDb();
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// Trims and collapses internal whitespace; preserves case.
  String _normalizeTag(String raw) =>
      raw.trim().replaceAll(_whitespaceRun, ' ');

  /// Adds [rawTag] to the currently selected image's tags (normalized,
  /// deduped). No-op if the normalized result is empty or no image is
  /// selected.
  Future<void> addTag(String rawTag) async {
    final AppImage? current = _currentDisplayedImage;
    if (current == null) {
      return;
    }
    final String tag = _normalizeTag(rawTag);
    if (tag.isEmpty) {
      return;
    }
    if (current.tags.contains(tag)) {
      return;
    }
    await setTags(<String>[...current.tags, tag]);
  }

  /// Removes [tag] from the currently selected image's tags. No-op if the
  /// tag is absent or no image is selected.
  Future<void> removeTag(String tag) async {
    final AppImage? current = _currentDisplayedImage;
    if (current == null) {
      return;
    }
    if (!current.tags.contains(tag)) {
      return;
    }
    await setTags(current.tags.where((String t) => t != tag).toList());
  }

  /// Replaces the currently selected image's tags with [rawTags]
  /// (each normalized; empties dropped; duplicates removed, preserving
  /// order).
  Future<void> setTags(List<String> rawTags) async {
    final AppImage? current = _currentDisplayedImage;
    if (current == null) {
      return;
    }

    final List<String> normalized = <String>[];
    final Set<String> seen = <String>{};
    for (final String raw in rawTags) {
      final String tag = _normalizeTag(raw);
      if (tag.isEmpty || seen.contains(tag)) {
        continue;
      }
      seen.add(tag);
      normalized.add(tag);
    }

    final AppImage updated = current.copyWith(tags: normalized);
    final List<AppImage> updatedImages = List<AppImage>.from(_state.images);
    final int index = updatedImages.indexWhere(
      (AppImage i) => i.id == current.id,
    );
    if (index == -1) {
      return;
    }
    updatedImages[index] = updated;
    _update(_state.copyWith(images: updatedImages));
    await _saveDb();
  }
}

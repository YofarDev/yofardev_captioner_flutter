part of 'image_list_cubit.dart';

enum SortBy { name, size, caption }

class ImageListState extends Equatable {
  final List<AppImage> images;
  final SortBy sortBy;
  final bool sortAscending;
  final String? folderPath;
  final String? currentImageId;
  final int occurrencesCount;
  final List<String> occurrenceFileNames;
  final String searchQuery;
  final bool caseSensitive;
  final List<String> categories;
  final Map<String, String> categoryFormats;
  final String? activeCategory;

  /// Per-image captioning guidance keyed by image file path. Persisted to
  /// db.json (id-keyed) across sessions and rebuilt path-keyed on folder open.
  /// When empty for an image, no guidance is injected for it.
  final Map<String, String> imageGuidance;

  /// Global enable for guidance injection. When false, [imageGuidance] is
  /// ignored by both captioning paths even if populated.
  final bool guidanceEnabled;

  const ImageListState({
    this.images = const <AppImage>[],
    this.sortBy = SortBy.name,
    this.sortAscending = true,
    this.folderPath,
    this.currentImageId,
    this.occurrencesCount = 0,
    this.occurrenceFileNames = const <String>[],
    this.searchQuery = '',
    this.caseSensitive = false,
    this.categories = const <String>['default'],
    this.categoryFormats = const <String, String>{},
    this.activeCategory = 'default',
    this.imageGuidance = const <String, String>{},
    this.guidanceEnabled = false,
  });

  ImageListState copyWith({
    List<AppImage>? images,
    SortBy? sortBy,
    bool? sortAscending,
    String? folderPath,
    String? currentImageId,
    int? occurrencesCount,
    List<String>? occurrenceFileNames,
    String? searchQuery,
    bool? caseSensitive,
    List<String>? categories,
    Map<String, String>? categoryFormats,
    String? activeCategory,
    Map<String, String>? imageGuidance,
    bool? guidanceEnabled,
  }) {
    return ImageListState(
      images: images ?? this.images,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      folderPath: folderPath ?? this.folderPath,
      currentImageId: currentImageId ?? this.currentImageId,
      occurrencesCount: occurrencesCount ?? this.occurrencesCount,
      occurrenceFileNames: occurrenceFileNames ?? this.occurrenceFileNames,
      searchQuery: searchQuery ?? this.searchQuery,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      categories: categories ?? this.categories,
      categoryFormats: categoryFormats ?? this.categoryFormats,
      activeCategory: activeCategory ?? this.activeCategory,
      imageGuidance: imageGuidance ?? this.imageGuidance,
      guidanceEnabled: guidanceEnabled ?? this.guidanceEnabled,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        images,
        sortBy,
        sortAscending,
        folderPath,
        currentImageId,
        occurrencesCount,
        occurrenceFileNames,
        searchQuery,
        caseSensitive,
        categories,
        categoryFormats,
        activeCategory,
        imageGuidance,
        guidanceEnabled,
      ];
}

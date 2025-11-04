part of 'images_cubit.dart';

enum SortBy { name, size, caption }

class ImagesState extends Equatable {
  final List<AppImage> images;
  final int currentIndex;
  final String? folderPath;
  final SortBy sortBy;
  final bool sortAscending;
  final int occurrencesCount;
  final String? captioningProgress;
  final bool isCaptioning;

  const ImagesState({
    this.images = const <AppImage>[],
    this.currentIndex = 0,
    this.folderPath,
    this.sortBy = SortBy.name,
    this.sortAscending = true,
    this.occurrencesCount = 0,
    this.captioningProgress,
    this.isCaptioning = false,
  });

  @override
  List<Object?> get props => <Object?>[
    images,
    currentIndex,
    folderPath,
    sortBy,
    sortAscending,
    occurrencesCount,
    captioningProgress,
    isCaptioning,
  ];

  ImagesState copyWith({
    List<AppImage>? images,
    int? currentIndex,
    String? folderPath,
    SortBy? sortBy,
    bool? sortAscending,
    int? occurrencesCount,
    String? captioningProgress,
    bool? isCaptioning,
  }) {
    return ImagesState(
      images: images ?? this.images,
      currentIndex: currentIndex ?? this.currentIndex,
      folderPath: folderPath ?? this.folderPath,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      occurrencesCount: occurrencesCount ?? this.occurrencesCount,
      captioningProgress: captioningProgress ?? this.captioningProgress,
      isCaptioning: isCaptioning ?? this.isCaptioning,
    );
  }

  int get emptyCaptions =>
      images.where((AppImage image) => image.caption.isEmpty).length;
}

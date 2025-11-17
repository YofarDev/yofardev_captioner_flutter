part of 'image_list_cubit.dart';

enum SortBy { name, size, caption }

class ImageListState extends Equatable {
  final List<AppImage> images;
  final SortBy sortBy;
  final bool sortAscending;
  final String? folderPath;
  final int currentIndex;
  final int occurrencesCount;
  final List<String> occurrenceFileNames;

  const ImageListState({
    this.images = const <AppImage>[],
    this.sortBy = SortBy.name,
    this.sortAscending = true,
    this.folderPath,
    this.currentIndex = 0,
    this.occurrencesCount = 0,
    this.occurrenceFileNames = const <String>[],
  });

  ImageListState copyWith({
    List<AppImage>? images,
    SortBy? sortBy,
    bool? sortAscending,
    String? folderPath,
    int? currentIndex,
    int? occurrencesCount,
    List<String>? occurrenceFileNames,
  }) {
    return ImageListState(
      images: images ?? this.images,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      folderPath: folderPath ?? this.folderPath,
      currentIndex: currentIndex ?? this.currentIndex,
      occurrencesCount: occurrencesCount ?? this.occurrencesCount,
      occurrenceFileNames: occurrenceFileNames ?? this.occurrenceFileNames,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    images,
    sortBy,
    sortAscending,
    folderPath,
    currentIndex,
    occurrencesCount,
    occurrenceFileNames,
  ];
}

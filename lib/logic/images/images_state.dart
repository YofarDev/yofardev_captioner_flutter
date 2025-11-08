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
  final String? captioningError;
  final int totalImagesToCaption;
  final List<String> imagesBeingProcessed;

  final bool isConverting;
  final String? conversionLog;

  const ImagesState({
    this.images = const <AppImage>[],
    this.currentIndex = 0,
    this.folderPath,
    this.sortBy = SortBy.name,
    this.sortAscending = true,
    this.occurrencesCount = 0,
    this.captioningProgress,
    this.isCaptioning = false,
    this.captioningError,
    this.totalImagesToCaption = 0,
    this.imagesBeingProcessed = const <String>[],
    this.isConverting = false,
    this.conversionLog,
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
    captioningError,
    totalImagesToCaption,
    imagesBeingProcessed,
    isConverting,
    conversionLog,
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
    String? captioningError,
    int? totalImagesToCaption,
    List<String>? imagesBeingProcessed,
    bool? isConverting,
    String? conversionLog,
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
      captioningError: captioningError ?? this.captioningError,
      totalImagesToCaption: totalImagesToCaption ?? this.totalImagesToCaption,
      imagesBeingProcessed: imagesBeingProcessed ?? this.imagesBeingProcessed,
      isConverting: isConverting ?? this.isConverting,
      conversionLog: conversionLog ?? this.conversionLog,
    );
  }

  int get emptyCaptions =>
      images.where((AppImage image) => image.caption.isEmpty).length;

  bool get hasErrors => images.any((AppImage image) => image.error != null);
}

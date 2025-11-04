part of 'images_cubit.dart';

enum SortBy { name, size }

class ImagesState extends Equatable {
  final List<AppImage> images;
  final int currentIndex;
  final String? folderPath;
  final SortBy sortBy;
  final bool sortAscending;
  final int occurrencesCount;
  final LlmConfigs llmConfigs;

  const ImagesState({
    this.images = const <AppImage>[],
    this.currentIndex = 0,
    this.folderPath,
    this.sortBy = SortBy.name,
    this.sortAscending = true,
    this.occurrencesCount = 0,
    this.llmConfigs = const LlmConfigs(
      configs: <LlmConfig>[],
      prompt:
          'Describe this image as one paragraph. Do not describe the atmosphere.',
    ),
  });

  @override
  List<Object?> get props => <Object?>[
    images,
    currentIndex,
    folderPath,
    sortBy,
    sortAscending,
    occurrencesCount,
    llmConfigs,
  ];

  ImagesState copyWith({
    List<AppImage>? images,
    int? currentIndex,
    String? folderPath,
    SortBy? sortBy,
    bool? sortAscending,
    int? occurrencesCount,
    LlmConfigs? llmConfigs,
  }) {
    return ImagesState(
      images: images ?? this.images,
      currentIndex: currentIndex ?? this.currentIndex,
      folderPath: folderPath ?? this.folderPath,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      occurrencesCount: occurrencesCount ?? this.occurrencesCount,
      llmConfigs: llmConfigs ?? this.llmConfigs,
    );
  }

  int get emptyCaptions =>
      images.where((AppImage image) => image.caption.isEmpty).length;
}

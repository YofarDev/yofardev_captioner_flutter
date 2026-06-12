part of 'structured_editor_cubit.dart';

enum StructuredEditorStatus { initial, saved, error }

class StructuredEditorState extends Equatable {
  const StructuredEditorState({
    required this.caption,
    required this.imageFile,
    required this.activeCategory,
    this.selectedElementIndex,
    this.hiddenElementIndices = const <int>{},
    this.status = StructuredEditorStatus.initial,
    this.error,
  });

  /// The mutable working copy of the caption.
  final IdeogramCaption caption;

  /// The image file for display and bbox thumbnail cropping.
  final File imageFile;

  /// Active category key for saving back.
  final String activeCategory;

  /// Index into caption.compositionalDeconstruction.elements, or null.
  final int? selectedElementIndex;

  /// Set of element indices whose bbox overlays are hidden.
  final Set<int> hiddenElementIndices;

  final StructuredEditorStatus status;
  final String? error;

  // Derived getters

  bool get isElementSelected => selectedElementIndex != null;

  IdeogramElement? get selectedElement {
    if (selectedElementIndex == null) return null;
    final List<IdeogramElement> elements =
        caption.compositionalDeconstruction.elements;
    if (selectedElementIndex! >= elements.length) return null;
    return elements[selectedElementIndex!];
  }

  StructuredEditorState copyWith({
    IdeogramCaption? caption,
    File? imageFile,
    String? activeCategory,
    int? selectedElementIndex,
    bool clearSelection = false,
    Set<int>? hiddenElementIndices,
    StructuredEditorStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return StructuredEditorState(
      caption: caption ?? this.caption,
      imageFile: imageFile ?? this.imageFile,
      activeCategory: activeCategory ?? this.activeCategory,
      selectedElementIndex: clearSelection
          ? null
          : (selectedElementIndex ?? this.selectedElementIndex),
      hiddenElementIndices: hiddenElementIndices ?? this.hiddenElementIndices,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    caption,
    imageFile,
    activeCategory,
    selectedElementIndex,
    hiddenElementIndices,
    status,
    error,
  ];
}

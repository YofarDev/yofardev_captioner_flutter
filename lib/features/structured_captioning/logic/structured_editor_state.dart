part of 'structured_editor_cubit.dart';

enum StructuredEditorStatus { initial, saved, error, recaptioning }

/// Lifecycle of the SAM3 bbox comparison cache for the current image.
enum SamComputeStatus { idle, computing, ready, error }

class StructuredEditorState extends Equatable {
  const StructuredEditorState({
    required this.caption,
    required this.imageFile,
    required this.activeCategory,
    this.selectedElementIndex,
    this.hiddenElementIndices = const <int>{},
    this.elementTitles = const <int, String>{},
    this.status = StructuredEditorStatus.initial,
    this.error,
    this.recaptioningElementIndex,
    this.samBboxByIndex,
    this.showSamBboxes = false,
    this.samComputeStatus = SamComputeStatus.idle,
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

  /// UI-only labels per element index. Never serialized — exists only to help
  /// the user tell layers apart in the panel.
  final Map<int, String> elementTitles;

  final StructuredEditorStatus status;
  final String? error;

  /// Index of the element currently being recaptioned, or null. Drives the
  /// per-element spinner in the UI.
  final int? recaptioningElementIndex;

  /// Cached SAM3 detections, keyed by element index. `null` = not yet
  /// computed for this image; empty map = computed but SAM found nothing.
  /// Never serialized — lives outside [caption].
  final Map<int, List<int>>? samBboxByIndex;

  /// When true, the canvas shows SAM3 bboxes instead of the saved (VLM)
  /// bboxes. Editing is disabled while this is true.
  final bool showSamBboxes;

  /// Lifecycle of [samBboxByIndex] for AppBar icon state.
  final SamComputeStatus samComputeStatus;

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
    Map<int, String>? elementTitles,
    StructuredEditorStatus? status,
    String? error,
    bool clearError = false,
    int? recaptioningElementIndex,
    bool clearRecaptioning = false,
    Map<int, List<int>>? samBboxByIndex,
    bool? showSamBboxes,
    SamComputeStatus? samComputeStatus,
    bool clearSamCache = false,
  }) {
    return StructuredEditorState(
      caption: caption ?? this.caption,
      imageFile: imageFile ?? this.imageFile,
      activeCategory: activeCategory ?? this.activeCategory,
      selectedElementIndex: clearSelection
          ? null
          : (selectedElementIndex ?? this.selectedElementIndex),
      hiddenElementIndices: hiddenElementIndices ?? this.hiddenElementIndices,
      elementTitles: elementTitles ?? this.elementTitles,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      recaptioningElementIndex: clearRecaptioning
          ? null
          : (recaptioningElementIndex ?? this.recaptioningElementIndex),
      samBboxByIndex: clearSamCache
          ? null
          : (samBboxByIndex ?? this.samBboxByIndex),
      showSamBboxes: !clearSamCache && (showSamBboxes ?? this.showSamBboxes),
      samComputeStatus: clearSamCache
          ? SamComputeStatus.idle
          : (samComputeStatus ?? this.samComputeStatus),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    caption,
    imageFile,
    activeCategory,
    selectedElementIndex,
    hiddenElementIndices,
    elementTitles,
    status,
    error,
    recaptioningElementIndex,
    samBboxByIndex,
    showSamBboxes,
    samComputeStatus,
  ];
}

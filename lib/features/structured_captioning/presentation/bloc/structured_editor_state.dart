part of 'structured_editor_cubit.dart';

enum StructuredEditorStatus { initial, saved, error, recaptioning }

/// Lifecycle of the SAM3 bbox comparison cache for the current image.
enum SamComputeStatus { idle, computing, ready, error }

class StructuredEditorState extends Equatable {
  const StructuredEditorState({
    required this.caption,
    required this.imageFile,
    required this.activeCategory,
    this.format = CaptionFormat.ideogram,
    this.mossMeta = const <String>[],
    this.mossCanvas,
    this.mossWidth = 1024,
    this.mossHeight = 1024,
    this.selectedElementIndex,
    this.hiddenElementIndices = const <int>{},
    this.lockedIndices = const <int>{},
    this.elementTitles = const <int, String>{},
    this.status = StructuredEditorStatus.initial,
    this.error,
    this.recaptioningElementIndex,
    this.recaptioningStyle = false,
    this.samBboxByIndex,
    this.showSamBboxes = false,
    this.samComputeStatus = SamComputeStatus.idle,
    this.showBboxText = false,
  });

  /// The mutable working copy of the caption. For MOSS captions this is the
  /// index-preserving Ideogram **view** — all element editing (canvas, layers,
  /// recaption) runs on it and the MOSS JSON is re-derived at save time.
  final IdeogramCaption caption;

  /// Which structured format this caption serializes to.
  final CaptionFormat format;

  /// MOSS-only: editable `summary.meta` tag list. Empty for Ideogram.
  final List<String> mossMeta;

  /// MOSS-only: `summary.canvas` value, when set.
  final String? mossCanvas;

  /// MOSS-only: canvas dimensions (positive multiples of 16).
  final int mossWidth;
  final int mossHeight;

  bool get isMoss => format == CaptionFormat.moss;

  /// The image file for display and bbox thumbnail cropping.
  final File imageFile;

  /// Active category key for saving back.
  final String activeCategory;

  /// Index into caption.compositionalDeconstruction.elements, or null.
  final int? selectedElementIndex;

  /// Set of element indices whose bbox overlays are hidden.
  final Set<int> hiddenElementIndices;

  /// Set of element indices whose bbox is locked (cannot be moved/resized).
  final Set<int> lockedIndices;

  /// UI-only labels per element index. Never serialized — exists only to help
  /// the user tell layers apart in the panel.
  final Map<int, String> elementTitles;

  final StructuredEditorStatus status;
  final String? error;

  /// Index of the element currently being recaptioned, or null. Drives the
  /// per-element spinner in the UI.
  final int? recaptioningElementIndex;

  /// True while a whole-style recaption is in flight. Drives the style-section
  /// spinner and disables the style fields.
  final bool recaptioningStyle;

  /// Cached SAM3 detections, keyed by element index. `null` = not yet
  /// computed for this image; empty map = computed but SAM found nothing.
  /// Never serialized — lives outside [caption].
  final Map<int, List<int>>? samBboxByIndex;

  /// When true, the canvas shows SAM3 bboxes instead of the saved (VLM)
  /// bboxes. Editing is disabled while this is true.
  final bool showSamBboxes;

  /// Lifecycle of [samBboxByIndex] for AppBar icon state.
  final SamComputeStatus samComputeStatus;

  /// When false, the canvas hides the text labels from bboxes (shows only
  /// colored squares).
  final bool showBboxText;

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
    CaptionFormat? format,
    List<String>? mossMeta,
    String? mossCanvas,
    bool clearMossCanvas = false,
    int? mossWidth,
    int? mossHeight,
    int? selectedElementIndex,
    bool clearSelection = false,
    Set<int>? hiddenElementIndices,
    Set<int>? lockedIndices,
    Map<int, String>? elementTitles,
    StructuredEditorStatus? status,
    String? error,
    bool clearError = false,
    int? recaptioningElementIndex,
    bool clearRecaptioning = false,
    bool? recaptioningStyle,
    bool clearRecaptioningStyle = false,
    Map<int, List<int>>? samBboxByIndex,
    bool? showSamBboxes,
    SamComputeStatus? samComputeStatus,
    bool? showBboxText,
    bool clearSamCache = false,
  }) {
    return StructuredEditorState(
      caption: caption ?? this.caption,
      imageFile: imageFile ?? this.imageFile,
      activeCategory: activeCategory ?? this.activeCategory,
      format: format ?? this.format,
      mossMeta: mossMeta ?? this.mossMeta,
      mossCanvas: clearMossCanvas ? null : (mossCanvas ?? this.mossCanvas),
      mossWidth: mossWidth ?? this.mossWidth,
      mossHeight: mossHeight ?? this.mossHeight,
      selectedElementIndex: clearSelection
          ? null
          : (selectedElementIndex ?? this.selectedElementIndex),
      hiddenElementIndices: hiddenElementIndices ?? this.hiddenElementIndices,
      lockedIndices: lockedIndices ?? this.lockedIndices,
      elementTitles: elementTitles ?? this.elementTitles,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      recaptioningElementIndex: clearRecaptioning
          ? null
          : (recaptioningElementIndex ?? this.recaptioningElementIndex),
      recaptioningStyle:
          !clearRecaptioningStyle &&
          (recaptioningStyle ?? this.recaptioningStyle),
      samBboxByIndex: clearSamCache
          ? null
          : (samBboxByIndex ?? this.samBboxByIndex),
      showSamBboxes: !clearSamCache && (showSamBboxes ?? this.showSamBboxes),
      samComputeStatus: clearSamCache
          ? SamComputeStatus.idle
          : (samComputeStatus ?? this.samComputeStatus),
      showBboxText: showBboxText ?? this.showBboxText,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    caption,
    imageFile,
    activeCategory,
    format,
    mossMeta,
    mossCanvas,
    mossWidth,
    mossHeight,
    selectedElementIndex,
    hiddenElementIndices,
    lockedIndices,
    elementTitles,
    status,
    error,
    recaptioningElementIndex,
    recaptioningStyle,
    samBboxByIndex,
    showSamBboxes,
    samComputeStatus,
    showBboxText,
  ];
}

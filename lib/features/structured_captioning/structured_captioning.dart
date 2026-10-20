/// Public API of the structured_captioning feature.
///
/// Other features and the composition root may depend only on what this
/// barrel exports — never on feature-internal files.
library;

export 'domain/models/apply_structured_overrides.dart'
    show applyStructuredOverrides;
export 'presentation/bloc/structured_captioning_cubit.dart'
    show StructuredCaptioningCubit, StructuredCaptioningState;
export 'presentation/bloc/structured_editor_cubit.dart'
    show StructuredEditorCubit, StructuredEditorState;
export 'presentation/pages/structured_editor_page.dart'
    show StructuredEditorPage;
export 'presentation/widgets/bbox_overlay.dart'
    show BboxElement, BboxOverlayImage;
export 'presentation/widgets/ideogram_caption_summary_card.dart'
    show IdeogramCaptionSummaryCard;

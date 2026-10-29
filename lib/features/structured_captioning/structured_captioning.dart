/// Public API of the structured_captioning feature.
///
/// Other features and the composition root may depend only on what this
/// barrel exports — never on feature-internal files.
library;

export 'domain/models/structured_mode.dart' show StructuredMode;
export 'domain/repositories/structured_caption_repository.dart'
    show IStructuredCaptionRepository;
export 'domain/services/layer_title_store.dart' show LayerTitleStore;

export 'presentation/bloc/structured_captioning_cubit.dart'
    show
        StructuredCaptioningCubit,
        StructuredCaptioningState,
        StructuredCaptioningStatus;
export 'presentation/bloc/structured_editor_cubit.dart'
    show StructuredEditorCubit, StructuredEditorParams, StructuredEditorState;
export 'presentation/pages/structured_editor_page.dart'
    show StructuredEditorPage;
export 'presentation/widgets/bbox_overlay.dart'
    show BboxElement, BboxOverlayImage;
export 'presentation/widgets/structured_caption_summary_card.dart'
    show StructuredCaptionSummaryCard;

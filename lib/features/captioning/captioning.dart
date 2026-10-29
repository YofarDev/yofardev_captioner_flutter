/// Public API of the captioning feature.
///
/// Other features and the composition root may depend only on what this
/// barrel exports — never on feature-internal files.
library;

export 'domain/models/batch_apply_template.dart' show BatchApplyTemplate;
export 'domain/models/caption_options.dart' show CaptionOptions;
export 'domain/repositories/captioning_repository.dart'
    show ICaptioningRepository;
export 'domain/utils/ideogram_json.dart';
export 'presentation/bloc/batch_apply/batch_json_apply_cubit.dart'
    show BatchJsonApplyCubit;
export 'presentation/bloc/batch_apply/batch_json_apply_state.dart'
    show BatchJsonApplyState;
export 'presentation/bloc/captioning_cubit.dart'
    show CaptioningCubit, CaptioningState;
export 'presentation/bloc/format_conversion/convert_format_cubit.dart'
    show ConvertFormatCubit;
export 'presentation/bloc/format_conversion/convert_format_state.dart'
    show
        ConvertFormatCompleted,
        ConvertFormatError,
        ConvertFormatInProgress,
        ConvertFormatInitial,
        ConvertFormatState;
export 'presentation/bloc/legacy_moss_repair/legacy_moss_repair_cubit.dart'
    show RepairLegacyMossCubit;
export 'presentation/bloc/legacy_moss_repair/legacy_moss_repair_state.dart'
    show
        LegacyMossRepairCompleted,
        LegacyMossRepairInProgress,
        LegacyMossRepairInitial,
        LegacyMossRepairPreview,
        LegacyMossRepairState,
        MossRepairCandidate;
export 'presentation/widgets/caption_controls.dart'
    show
        CancelStructuredCallback,
        CaptionControls,
        RunStructuredCallback,
        StructuredRunProgress;
export 'presentation/widgets/caption_text_area.dart' show CaptionTextArea;
export 'presentation/widgets/convert_format_dialog.dart'
    show ConvertFormatDialog;
export 'presentation/widgets/legacy_moss_repair_dialog.dart'
    show LegacyMossRepairDialog;

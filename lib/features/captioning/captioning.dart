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
export 'presentation/widgets/caption_controls.dart' show CaptionControls;
export 'presentation/widgets/caption_text_area.dart' show CaptionTextArea;

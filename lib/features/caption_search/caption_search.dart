/// Public API of the caption_search feature.
///
/// Other features and the composition root may depend only on what this
/// barrel exports — never on feature-internal files.
library;

export 'domain/services/autocomplete_engine.dart';
// Filtering (FilterQuery / FilterParser) moved to image_list in Phase 3b;
// consume those via the image_list barrel instead.
export 'presentation/bloc/caption_search_cubit.dart'
    show CaptionSearchCubit, CaptionSearchState;
export 'presentation/widgets/caption_search_bar.dart' show CaptionSearchBar;

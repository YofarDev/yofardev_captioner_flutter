/// Public API of the caption_search feature.
///
/// Other features and the composition root may depend only on what this
/// barrel exports — never on feature-internal files.
library;

export 'domain/models/filter_query.dart';
export 'domain/services/autocomplete_engine.dart';
export 'domain/services/filter_parser.dart';
export 'presentation/bloc/caption_search_cubit.dart'
    show CaptionSearchCubit, CaptionSearchState;
export 'presentation/widgets/caption_search_bar.dart' show CaptionSearchBar;

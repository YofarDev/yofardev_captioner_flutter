/// Public API of the caption_session module: the per-tab caption session,
/// its file-store port, filter engine, state model, and the tab-session
/// registry. Pure domain — no presentation, no data, no DI.
library;

export 'domain/models/filter_query.dart';
export 'domain/models/image_list_state.dart' show ImageListState, SortBy;
export 'domain/services/caption_session_service.dart';
export 'domain/services/caption_session_snapshot.dart';
export 'domain/services/filter_parser.dart';
export 'domain/services/filter_parser_engine.dart'
    show FilterParserCaptionEngine;
export 'domain/services/tab_session_registry.dart'
    show TabSessionInfo, TabSessionRegistry;

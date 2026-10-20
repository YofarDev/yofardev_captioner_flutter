/// Public API of the tab_manager feature.
///
/// Other features and the composition root may depend only on what this
/// barrel exports — never on feature-internal files.
library;

export 'domain/models/app_tab.dart' show AppTab;
export 'domain/services/tab_session_registry.dart' show TabSessionRegistry;
export 'presentation/bloc/tab_manager_cubit.dart'
    show TabManagerCubit, TabManagerState;
export 'presentation/widgets/tab_bar_widget.dart' show TabBarWidget;
export 'presentation/widgets/tab_content.dart' show TabContent;

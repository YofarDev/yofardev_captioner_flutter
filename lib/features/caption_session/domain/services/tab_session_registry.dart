import 'caption_session_service.dart';

/// Read-only snapshot of one tab, pushed into [TabSessionRegistry] by the
/// `TabManagerCubit` whenever its UI state changes. Lets non-widget consumers
/// (the Agent API) see which tabs exist without touching any cubit.
class TabSessionInfo {
  const TabSessionInfo({
    required this.id,
    required this.folderPath,
    required this.displayName,
    required this.isActive,
  });

  final String id;
  final String? folderPath;
  final String displayName;
  final bool isActive;
}

/// Owns the per-tab [CaptionSessionService] map and a snapshot of the tab
/// list. Both `TabManagerCubit` (which creates/disposes sessions with the tab
/// lifecycle and pushes snapshots) and `AgentApiService` (which only reads)
/// share one instance, so no data-layer service ever needs a cubit.
class TabSessionRegistry {
  /// Factory for new sessions. Bound by the owning cubit so session
  /// construction (file store, filter engine, cache-eviction hook) stays in
  /// one place.
  CaptionSessionService Function()? _factory;

  final Map<String, CaptionSessionService> _sessions =
      <String, CaptionSessionService>{};

  List<TabSessionInfo> _tabs = const <TabSessionInfo>[];

  /// The session factory used by [ensure]. Assigned once by the owning cubit
  /// at construction and never rebound or cleared — [disposeAll] tears down
  /// sessions but intentionally leaves the factory (and the tab snapshot)
  /// in place, so the registry keeps working for the life of the app even
  /// after all tabs close.
  CaptionSessionService Function()? get sessionFactory => _factory;
  set sessionFactory(CaptionSessionService Function() factory) =>
      _factory = factory;

  /// The session owning [tabId], created synchronously on first request.
  CaptionSessionService ensure(String tabId) =>
      _sessions.putIfAbsent(tabId, _create);

  /// The session owning [tabId] if one exists; never creates.
  CaptionSessionService? peek(String tabId) => _sessions[tabId];

  /// Alias of [ensure] for readers that expect a live tab's session.
  CaptionSessionService sessionFor(String tabId) => ensure(tabId);

  /// Disposes and removes the session for [tabId] (tab closed).
  void dispose(String tabId) {
    _sessions.remove(tabId)?.dispose();
  }

  /// Disposes every session (app teardown).
  void disposeAll() {
    for (final CaptionSessionService session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
  }

  /// Replaces the tab snapshot. Order matters: [tabForFolder] returns the
  /// first match, mirroring the cubit's tab-list search.
  void updateTabs(List<TabSessionInfo> tabs) {
    _tabs = List<TabSessionInfo>.unmodifiable(tabs);
  }

  List<TabSessionInfo> get tabs => _tabs;

  /// The first tab whose folder is [folder], or null.
  TabSessionInfo? tabForFolder(String folder) {
    for (final TabSessionInfo tab in _tabs) {
      if (tab.folderPath == folder) return tab;
    }
    return null;
  }

  CaptionSessionService _create() {
    final CaptionSessionService Function()? factory = _factory;
    if (factory == null) {
      throw StateError(
        'TabSessionRegistry.ensure called before bind() — no session factory',
      );
    }
    return factory();
  }
}

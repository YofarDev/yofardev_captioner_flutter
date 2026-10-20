import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/cache_service.dart';
import '../../../image_list/data/repositories/app_file_utils.dart';
import '../../../image_list/image_list.dart';
import '../../domain/models/app_tab.dart';
import '../../domain/services/tab_session_registry.dart';

part 'tab_manager_state.dart';

class TabManagerCubit extends Cubit<TabManagerState> {
  TabManagerCubit({
    CacheService? cacheService,
    AppFileUtils? fileUtils,
    CaptionFilterEngine? filterEngine,
    TabSessionRegistry? sessionRegistry,
  }) : _cacheService = cacheService ?? const CacheService(),
       _fileUtils = fileUtils ?? AppFileUtils(cacheService: cacheService),
       _filterEngine = filterEngine ?? const FilterParserCaptionEngine(),
       super(const TabManagerState(tabs: <AppTab>[AppTab(id: 'default')])) {
    _sessions = sessionRegistry ?? TabSessionRegistry();
    _sessions.sessionFactory = _createSession;
    // The default tab's session exists before any widget builds.
    _ensureSession(state.activeTab.id);
    _syncRegistry(state);
  }

  final CacheService _cacheService;
  final AppFileUtils _fileUtils;
  final CaptionFilterEngine _filterEngine;

  /// Owns the per-tab sessions. Created locally by default, or shared from DI
  /// so non-widget consumers (the Agent API) can reach the same sessions
  /// without depending on this cubit.
  late final TabSessionRegistry _sessions;

  @override
  void onChange(Change<TabManagerState> change) {
    super.onChange(change);
    _persistTabs(change.nextState);
    _updateWindowTitle(change.nextState);
    // onChange runs BEFORE this.state is updated — always sync from
    // change.nextState.
    _syncRegistry(change.nextState);
  }

  /// Mirrors the tab list into the session registry so non-widget consumers
  /// see the same tabs without reading cubit state.
  void _syncRegistry(TabManagerState registryState) {
    final List<AppTab> tabs = registryState.tabs;
    final int activeIndex = registryState.activeTabIndex;
    _sessions.updateTabs(<TabSessionInfo>[
      for (int i = 0; i < tabs.length; i++)
        TabSessionInfo(
          id: tabs[i].id,
          folderPath: tabs[i].folderPath,
          displayName: tabs[i].displayName,
          isActive: i == activeIndex,
        ),
    ]);
  }

  void _persistTabs(TabManagerState state) {
    final List<String> paths = state.tabs
        .where((AppTab t) => t.folderPath != null)
        .map((AppTab t) => t.folderPath!)
        .toList();
    _cacheService.saveTabPaths(paths);
    _cacheService.saveActiveTabIndex(state.activeTabIndex);
  }

  void _updateWindowTitle(TabManagerState state) {
    final AppTab active = state.activeTab;
    if (active.folderPath == null) {
      windowManager.setTitle('Yofardev Captioner');
      return;
    }
    windowManager.setTitle('Yofardev Captioner ➡️ "${active.folderPath}"');
  }

  CaptionSessionService _createSession() {
    late final CaptionSessionService session;
    return session = CaptionSessionService(
      fileStore: _fileUtils,
      filterEngine: _filterEngine,
      // Ordering dependency: onBeforeFolderLoad runs SYNCHRONOUSLY at the
      // start of every folder (re)load, BEFORE the session clears its image
      // list — so `session.current.state.images` here still sees the PREVIOUS
      // folder's images, which is exactly what the Flutter image-cache
      // eviction needs. Do not defer this callback or read it after the load.
      onBeforeFolderLoad: () => evictImageCache(session.current.state.images),
    );
  }

  CaptionSessionService _ensureSession(String tabId) => _sessions.ensure(tabId);

  /// The session owning [tabId]. Created on demand so it can never be null
  /// for a live tab.
  CaptionSessionService sessionFor(String tabId) {
    if (_sessions.peek(tabId) == null) {
      // Resolved lazily so constructing a TabManagerCubit never requires a
      // configured DI container (widget tests build bare instances).
      locator<Logger>().warning(
        'sessionFor: unknown tabId "$tabId" — creating a session on demand',
      );
    }
    return _ensureSession(tabId);
  }

  void addTab(String? folderPath) {
    final String tabId = 'tab_${DateTime.now().millisecondsSinceEpoch}';
    final List<AppTab> newTabs = List<AppTab>.from(state.tabs)
      ..add(
        AppTab(
          id: tabId,
          folderPath: folderPath,
          displayName: folderPath?.split('/').last ?? 'New Tab',
        ),
      );
    _ensureSession(tabId);
    emit(state.copyWith(tabs: newTabs, activeTabIndex: newTabs.length - 1));
  }

  void switchTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    emit(state.copyWith(activeTabIndex: index));
  }

  void closeTab(String tabId) {
    if (state.tabs.length <= 1) return;
    final int index = state.tabs.indexWhere((AppTab t) => t.id == tabId);
    if (index == -1) return;
    final List<AppTab> newTabs = List<AppTab>.from(state.tabs)..removeAt(index);
    int newIndex = state.activeTabIndex;
    if (index < newIndex) {
      newIndex--;
    } else if (index == newIndex && newIndex >= newTabs.length) {
      newIndex = newTabs.length - 1;
    }
    _sessions.dispose(tabId);
    emit(state.copyWith(tabs: newTabs, activeTabIndex: newIndex));
  }

  void updateTabDisplayName(String tabId, String name) {
    final List<AppTab> newTabs = state.tabs.map((AppTab t) {
      if (t.id == tabId) return t.copyWith(displayName: name);
      return t;
    }).toList();
    emit(state.copyWith(tabs: newTabs));
  }

  void updateTabFolderPath(String tabId, String folderPath) {
    final List<AppTab> newTabs = state.tabs.map((AppTab t) {
      if (t.id == tabId) {
        return t.copyWith(
          folderPath: folderPath,
          displayName: folderPath.split('/').last,
        );
      }
      return t;
    }).toList();
    emit(state.copyWith(tabs: newTabs));
  }

  AppTab? findTabByFolderPath(String folderPath) {
    for (final AppTab tab in state.tabs) {
      if (tab.folderPath == folderPath) return tab;
    }
    return null;
  }

  void activateOrAddTab(String folderPath) {
    final AppTab? existing = findTabByFolderPath(folderPath);
    if (existing != null) {
      switchTab(state.tabs.indexOf(existing));
      return;
    }
    addTab(folderPath);
  }

  String get activeTabId => state.activeTab.id;

  @override
  Future<void> close() {
    _sessions.disposeAll();
    return super.close();
  }
}

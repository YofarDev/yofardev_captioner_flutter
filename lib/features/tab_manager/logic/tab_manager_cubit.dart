import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/services/cache_service.dart';
import '../../image_list/data/repositories/app_file_utils.dart';
import '../../image_list/data/services/filter_parser_engine.dart';
import '../../image_list/domain/services/caption_session_service.dart';
import '../../image_list/logic/image_cache_eviction.dart';
import '../data/models/app_tab.dart';

part 'tab_manager_state.dart';

class TabManagerCubit extends Cubit<TabManagerState> {
  TabManagerCubit({
    CacheService? cacheService,
    AppFileUtils? fileUtils,
    CaptionFilterEngine? filterEngine,
  }) : _cacheService = cacheService ?? const CacheService(),
       _fileUtils = fileUtils ?? AppFileUtils(cacheService: cacheService),
       _filterEngine = filterEngine ?? const FilterParserCaptionEngine(),
       super(const TabManagerState(tabs: <AppTab>[AppTab(id: 'default')])) {
    // The default tab's session exists before any widget builds.
    _ensureSession(state.activeTab.id);
  }

  final CacheService _cacheService;
  final AppFileUtils _fileUtils;
  final CaptionFilterEngine _filterEngine;

  /// One session per tab, created SYNCHRONOUSLY when the tab appears so
  /// consumers (home_page keyboard/file-open, Agent API, TabContent cubits)
  /// never wait for a widget to register anything.
  final Map<String, CaptionSessionService> _sessions =
      <String, CaptionSessionService>{};

  @override
  void onChange(Change<TabManagerState> change) {
    super.onChange(change);
    _persistTabs(change.nextState);
    _updateWindowTitle(change.nextState);
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
      onBeforeFolderLoad: () => evictImageCache(session.current.state.images),
    );
  }

  CaptionSessionService _ensureSession(String tabId) =>
      _sessions.putIfAbsent(tabId, _createSession);

  /// The session owning [tabId]. Created on demand so it can never be null
  /// for a live tab.
  CaptionSessionService sessionFor(String tabId) => _ensureSession(tabId);

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
    _sessions.remove(tabId)?.dispose();
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
    for (final CaptionSessionService session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
    return super.close();
  }
}

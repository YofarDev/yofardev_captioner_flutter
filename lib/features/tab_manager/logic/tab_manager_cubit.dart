import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/services/cache_service.dart';
import '../../image_list/logic/image_list_cubit.dart';
import '../data/models/app_tab.dart';

part 'tab_manager_state.dart';

class TabManagerCubit extends Cubit<TabManagerState> {
  TabManagerCubit()
    : super(const TabManagerState(tabs: <AppTab>[AppTab(id: 'default')]));

  final Map<String, ImageListCubit> _tabCubits = <String, ImageListCubit>{};

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
    CacheService.saveTabPaths(paths);
    CacheService.saveActiveTabIndex(state.activeTabIndex);
  }

  void _updateWindowTitle(TabManagerState state) {
    final AppTab active = state.activeTab;
    if (active.folderPath == null) {
      windowManager.setTitle('Yofardev Captioner');
      return;
    }
    windowManager.setTitle('Yofardev Captioner ➡️ "${active.folderPath}"');
  }

  void registerTabCubit(String tabId, ImageListCubit cubit) {
    _tabCubits[tabId] = cubit;
  }

  void unregisterTabCubit(String tabId) {
    _tabCubits.remove(tabId);
  }

  ImageListCubit? getCubitForTab(String tabId) => _tabCubits[tabId];

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
}

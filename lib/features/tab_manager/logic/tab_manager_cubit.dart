import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/app_tab.dart';

part 'tab_manager_state.dart';

class TabManagerCubit extends Cubit<TabManagerState> {
  TabManagerCubit()
      : super(const TabManagerState(tabs: <AppTab>[
          AppTab(id: 'default', displayName: 'New Tab'),
        ]));

  void addTab(String? folderPath) {
    final String tabId = 'tab_${DateTime.now().millisecondsSinceEpoch}';
    final List<AppTab> newTabs = List<AppTab>.from(state.tabs)
      ..add(AppTab(
        id: tabId,
        folderPath: folderPath,
        displayName: folderPath?.split('/').last ?? 'New Tab',
      ));
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

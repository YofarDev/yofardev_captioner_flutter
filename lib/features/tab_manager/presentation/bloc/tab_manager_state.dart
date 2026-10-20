part of 'tab_manager_cubit.dart';

class TabManagerState extends Equatable {
  const TabManagerState({
    this.tabs = const <AppTab>[],
    this.activeTabIndex = 0,
  });

  final List<AppTab> tabs;
  final int activeTabIndex;

  AppTab get activeTab => tabs[activeTabIndex];

  TabManagerState copyWith({List<AppTab>? tabs, int? activeTabIndex}) {
    return TabManagerState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
    );
  }

  @override
  List<Object?> get props => <Object?>[tabs, activeTabIndex];
}

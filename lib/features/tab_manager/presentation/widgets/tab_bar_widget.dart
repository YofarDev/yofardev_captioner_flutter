import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/app_tab.dart';
import '../../logic/tab_manager_cubit.dart';

class TabBarWidget extends StatelessWidget {
  const TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TabManagerCubit, TabManagerState>(
      builder: (BuildContext context, TabManagerState state) {
        return Container(
          height: 36,
          color: tabBarBg,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: state.tabs.length + 1,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 2),
            itemBuilder: (BuildContext context, int index) {
              if (index == state.tabs.length) {
                return _AddTabButton(
                  onPressed: () => context.read<TabManagerCubit>().addTab(null),
                );
              }
              final AppTab tab = state.tabs[index];
              final bool isActive = index == state.activeTabIndex;
              return _TabItem(
                tab: tab,
                isActive: isActive,
                canClose: state.tabs.length > 1,
                onTap: () => context.read<TabManagerCubit>().switchTab(index),
                onClose: () => context.read<TabManagerCubit>().closeTab(tab.id),
              );
            },
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.canClose,
    required this.onTap,
    required this.onClose,
  });

  final AppTab tab;
  final bool isActive;
  final bool canClose;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? tabActiveBg : tabInactiveBg,
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: isActive ? tabActiveAccent : Colors.transparent,
            ),
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        constraints: const BoxConstraints(maxWidth: 180),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                tab.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? tabActiveFg : tabInactiveFg,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            if (canClose) ...<Widget>[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 14, color: tabInactiveFg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddTabButton extends StatelessWidget {
  const _AddTabButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Center(child: Icon(Icons.add, size: 16, color: tabInactiveFg)),
      ),
    );
  }
}

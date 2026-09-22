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
          decoration: const BoxDecoration(
            color: tabBarBg,
            border: Border(bottom: BorderSide(color: hairline)),
          ),
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

class _TabItem extends StatefulWidget {
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
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? tabActiveBg
                : _isHovered
                ? hoverOverlay
                : tabInactiveBg,
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: widget.isActive
                    ? tabActiveAccent
                    : _isHovered
                    ? hairline
                    : Colors.transparent,
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
                  widget.tab.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isActive
                        ? tabActiveFg
                        : _isHovered
                        ? textSecondary
                        : tabInactiveFg,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              if (widget.canClose) ...<Widget>[
                const SizedBox(width: 4),
                _TabCloseButton(onClose: widget.onClose),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabCloseButton extends StatefulWidget {
  const _TabCloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_TabCloseButton> createState() => _TabCloseButtonState();
}

class _TabCloseButtonState extends State<_TabCloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onClose,
        child: Icon(
          Icons.close,
          size: 13,
          color: _isHovered ? destructive : tabInactiveFg,
        ),
      ),
    );
  }
}

class _AddTabButton extends StatefulWidget {
  const _AddTabButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AddTabButton> createState() => _AddTabButtonState();
}

class _AddTabButtonState extends State<_AddTabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _isHovered ? hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              size: 16,
              color: _isHovered ? textSecondary : tabInactiveFg,
            ),
          ),
        ),
      ),
    );
  }
}

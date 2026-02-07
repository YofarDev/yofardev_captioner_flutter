import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../image_list/logic/image_list_cubit.dart';

class CategoryTabBar extends StatelessWidget {
  const CategoryTabBar({super.key});

  static const double _height = 28.0;
  static const double _spacing = 2.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        if (state.categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: _height,
          child: Row(
            children: <Widget>[
              const SizedBox(width: 16),
              Expanded(
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.zero,
                  proxyDecorator: _proxyDecorator,
                  itemCount: state.categories.length,
                  onReorder: (int oldIndex, int newIndex) {
                    context.read<ImageListCubit>().reorderCategories(
                      oldIndex,
                      newIndex,
                    );
                  },
                  itemBuilder: (BuildContext context, int index) {
                    final String category = state.categories[index];
                    final bool isActive = category == state.activeCategory;
                    return _CategoryTab(
                      key: ValueKey<String>(category),
                      category: category,
                      isActive: isActive,
                      onTap: () {
                        context.read<ImageListCubit>().setActiveCategory(
                          category,
                        );
                      },
                      onMenuPress: () =>
                          _showCategoryOptions(context, category),
                    );
                  },
                ),
              ),
              const SizedBox(width: _spacing),
              _AddCategoryButton(
                onPressed: () => _showAddCategoryDialog(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Material(
          elevation: 4,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
          color: Colors.transparent,
          child: child,
        );
      },
      child: child,
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) => _CategoryDialog(
        title: 'Add Category',
        hintText: 'Category name',
        controller: controller,
        confirmText: 'Add',
        onConfirm: () {
          if (controller.text.trim().isNotEmpty) {
            context.read<ImageListCubit>().addCategory(controller.text.trim());
          }
        },
      ),
    );
  }

  void _showCategoryOptions(BuildContext context, String category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title: const Text(
                'Rename category',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, category);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete category',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, category);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String category) {
    final TextEditingController controller = TextEditingController(
      text: category,
    );
    showDialog(
      context: context,
      builder: (BuildContext context) => _CategoryDialog(
        title: 'Rename Category',
        hintText: 'New name',
        controller: controller,
        confirmText: 'Rename',
        onConfirm: () {
          if (controller.text.trim().isNotEmpty) {
            context.read<ImageListCubit>().renameCategory(
              category,
              controller.text.trim(),
            );
          }
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String category) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Category',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete "$category"? All captions in this category will be lost.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ImageListCubit>().removeCategory(category);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatefulWidget {
  const _CategoryTab({
    super.key,
    required this.category,
    required this.isActive,
    required this.onTap,
    required this.onMenuPress,
  });

  final String category;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onMenuPress;

  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ReorderableDragStartListener(
        index:
            context
                .findAncestorStateOfType<ReorderableListState>()
                ?.widget
                .itemCount ??
            0,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            height: CategoryTabBar._height,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.only(right: CategoryTabBar._spacing),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? lightGrey
                  : _isHovered
                  ? Colors.white.withAlpha(8)
                  : Colors.white.withAlpha(6),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.isActive
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: widget.isActive
                        ? Colors.white
                        : Colors.white.withAlpha(140),
                    height: 1.0,
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: _isHovered || widget.isActive ? 1.0 : 0.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(width: 6),
                      _MenuButton(onPressed: widget.onMenuPress),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.more_horiz,
            size: 13,
            color: Colors.white.withAlpha(120),
          ),
        ),
      ),
    );
  }
}

class _AddCategoryButton extends StatelessWidget {
  const _AddCategoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
        child: SizedBox(
          height: CategoryTabBar._height,
          width: CategoryTabBar._height,
          child: Icon(Icons.add, size: 16, color: Colors.white.withAlpha(100)),
        ),
      ),
    );
  }
}

class _CategoryDialog extends StatelessWidget {
  const _CategoryDialog({
    required this.title,
    required this.hintText,
    required this.controller,
    required this.confirmText,
    required this.onConfirm,
  });

  final String title;
  final String hintText;
  final TextEditingController controller;
  final String confirmText;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: darkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
          filled: true,
          fillColor: Colors.white.withAlpha(10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withAlpha(25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withAlpha(25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: lightPink.withAlpha(150)),
          ),
        ),
        autofocus: true,
        onSubmitted: (_) {
          onConfirm();
          Navigator.pop(context);
        },
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withAlpha(150)),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: lightPink,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            confirmText,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

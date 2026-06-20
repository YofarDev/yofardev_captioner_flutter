import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/app_image.dart';
import '../../logic/image_list_cubit.dart';

class TagEditor extends StatelessWidget {
  const TagEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        final ImageListCubit cubit = context.read<ImageListCubit>();
        final AppImage? image = cubit.currentDisplayedImage;
        if (image == null) return const SizedBox.shrink();

        final List<String> tags = image.tags;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(
            children: <Widget>[
              _TagsButton(
                tagCount: tags.length,
                onPressed: () => _showTagDialog(context, cubit, tags),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTagDialog(
    BuildContext context,
    ImageListCubit cubit,
    List<String> tags,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => _TagDialog(cubit: cubit, tags: tags),
    );
  }
}

class _TagsButton extends StatelessWidget {
  const _TagsButton({required this.tagCount, required this.onPressed});

  final int tagCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(color: hairline.withAlpha(80), width: 0.5),
          ),
        ),
        child: Text(
          tagCount > 0 ? '+Tags ($tagCount)' : '+Tags',
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _TagDialog extends StatefulWidget {
  const _TagDialog({required this.cubit, required this.tags});

  final ImageListCubit cubit;
  final List<String> tags;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final TextEditingController _controller;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _tags = List<String>.from(widget.tags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTags() {
    final String value = _controller.text;
    if (value.trim().isEmpty) return;
    final List<String> newTags = <String>[];
    for (final String part in value.split(',')) {
      final String trimmed = part.trim();
      if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
        newTags.add(trimmed);
      }
    }
    if (newTags.isEmpty) return;
    setState(() {
      _tags = <String>[..._tags, ...newTags];
      _controller.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags = _tags.where((String t) => t != tag).toList();
    });
  }

  void _save() {
    widget.cubit.setTags(_tags);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: panelDark,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Tags',
        style: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _tags.map((String tag) {
                    return Chip(
                      label: Text(
                        tag,
                        style: const TextStyle(
                          color: textPrimary,
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14,
                          color: textMuted),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: panelRaised,
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        color: textPrimary,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        hintText: 'add tag(s)\u2026',
                        hintStyle: TextStyle(
                          color: textMuted.withAlpha(80),
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: hairline, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: hairline, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              const BorderSide(color: textMuted, width: 0.5),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addTags(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 28,
                  child: TextButton(
                    onPressed: _addTags,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: textSecondary,
                      backgroundColor: panelRaised,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: textMuted, fontSize: 12,
                fontFamily: 'Inter'),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(
            'Save',
            style: TextStyle(color: textPrimary, fontSize: 12,
                fontFamily: 'Inter'),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/app_image.dart';
import '../../logic/image_list_cubit.dart';

class TagEditor extends StatefulWidget {
  const TagEditor({super.key});

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text;
    if (value.trim().isEmpty) {
      _controller.clear();
      return;
    }
    final ImageListCubit cubit = context.read<ImageListCubit>();
    for (final String part in value.split(',')) {
      final String trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        cubit.addTag(trimmed);
      }
    }
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        final AppImage? image =
            context.read<ImageListCubit>().currentDisplayedImage;
        if (image == null) return const SizedBox.shrink();

        final List<String> tags = image.tags;

        return Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: hairline, width: 0.5),
            ),
          ),
          child: Row(
            children: <Widget>[
              if (tags.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tags.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 2),
                    itemBuilder: (BuildContext context, int index) {
                      final String tag = tags[index];
                      return _TagChip(
                        label: tag,
                        onRemoved: () =>
                            context.read<ImageListCubit>().removeTag(tag),
                      );
                    },
                  ),
                ),
              if (tags.isNotEmpty) const SizedBox(width: 4),
              SizedBox(
                width: 100,
                height: 20,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontFamily: 'Inter',
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: tags.isEmpty ? 'add tag\u2026' : '+',
                    hintStyle: TextStyle(
                      color: textMuted.withAlpha(60),
                      fontSize: 11,
                      fontFamily: 'Inter',
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TagChip extends StatefulWidget {
  const _TagChip({required this.label, required this.onRemoved});

  final String label;
  final VoidCallback onRemoved;

  @override
  State<_TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<_TagChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onRemoved,
        child: Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: _hovered ? panelRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? textSecondary : textMuted,
                  fontSize: 11,
                  fontFamily: 'Inter',
                  height: 1.3,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Text(
                  '\u00d7',
                  style: TextStyle(
                    color: _hovered
                        ? textMuted
                        : textMuted.withAlpha(40),
                    fontSize: 10,
                    fontFamily: 'Inter',
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: panelDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Tags',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                  color: textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final String tag in tags)
                      _TagChip(
                        label: tag,
                        onRemoved: () =>
                            context.read<ImageListCubit>().removeTag(tag),
                      ),
                  ],
                ),
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    hintText: 'Add a tag\u2026',
                    hintStyle: const TextStyle(
                      color: textMuted,
                      fontSize: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: accentPink),
                    ),
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

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.onRemoved});

  final String label;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: panelRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: accentPink,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          IconButton(
            splashRadius: 14,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            padding: EdgeInsets.zero,
            iconSize: 14,
            onPressed: onRemoved,
            icon: const Icon(Icons.close, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

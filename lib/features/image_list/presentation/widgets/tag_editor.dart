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
                onPressed: () => _showTagDialog(context, cubit),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTagDialog(BuildContext context, ImageListCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => _TagDialog(cubit: cubit),
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
  const _TagDialog({required this.cubit});

  final ImageListCubit cubit;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
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

  // ponytail: writes through on every action — no buffered Save step.
  // Enter/comma split -> setTags normalizes+dedupes+persists in one DB write.
  void _commit() {
    final String value = _controller.text;
    if (value.trim().isEmpty) return;
    final AppImage? image = widget.cubit.currentDisplayedImage;
    if (image == null) return;
    final List<String> parsed = value
        .split(',')
        .map((String p) => p.trim())
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parsed.isEmpty) {
      _controller.clear();
      return;
    }
    widget.cubit.setTags(<String>[...image.tags, ...parsed]);
    Navigator.of(context).pop();
  }

  void _removeTag(String tag) => widget.cubit.removeTag(tag);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ImageListCubit>.value(
      value: widget.cubit,
      child: BlocBuilder<ImageListCubit, ImageListState>(
        builder: (BuildContext context, ImageListState state) {
          final AppImage? image = widget.cubit.currentDisplayedImage;
          final List<String> tags = image?.tags ?? const <String>[];
          return AlertDialog(
            backgroundColor: panelDark,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: hairline, width: 0.5),
            ),
            titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            contentPadding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            title: Row(
              children: <Widget>[
                const Text(
                  'Tags',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                if (tags.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: pinkSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: hairline, width: 0.5),
                    ),
                    child: Text(
                      '${tags.length}',
                      style: const TextStyle(
                        color: lightPink,
                        fontSize: 10,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 170),
                    child: tags.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'No tags yet — type one below.',
                              style: TextStyle(
                                color: textMuted.withAlpha(130),
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: tags
                                  .map(
                                    (String tag) => _TagChip(
                                      label: tag,
                                      onDeleted: () => _removeTag(tag),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontFamily: 'Inter',
                    ),
                    cursorColor: accentPink,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 11,
                      ),
                      hintText: 'Type a tag and press Enter…',
                      hintStyle: TextStyle(
                        color: textMuted.withAlpha(110),
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                      prefixIcon: Icon(
                        Icons.tag_rounded,
                        size: 14,
                        color: textMuted.withAlpha(140),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 26),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: hairline,
                          width: 0.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: hairline,
                          width: 0.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: accentPink,
                          width: 0.75,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _commit(),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Enter or comma to add  ·  saves instantly',
                    style: TextStyle(
                      color: textMuted.withAlpha(100),
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: lightPink,
                  minimumSize: const Size(56, 30),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: panelRaised,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: hairline, width: 0.5),
      ),
      padding: const EdgeInsets.only(left: 8, right: 4, top: 3, bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(width: 5),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(3),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close,
                size: 12,
                color: textMuted.withAlpha(150),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

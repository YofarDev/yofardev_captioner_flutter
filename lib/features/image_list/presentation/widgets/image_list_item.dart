import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/models/app_image.dart';
import '../../logic/image_list_cubit.dart';

class ImageListItem extends StatefulWidget {
  const ImageListItem({
    required this.image,
    required this.isSelected,
    required this.activeCategory,
    super.key,
  });

  final AppImage image;
  final bool isSelected;
  final String activeCategory;

  @override
  State<ImageListItem> createState() => _ImageListItemState();
}

class _ImageListItemState extends State<ImageListItem> {
  bool _isHovered = false;

  String _getSizeCategory() {
    if (widget.image.width > 0 && widget.image.height > 0) {
      final int minSize = widget.image.width < widget.image.height
          ? widget.image.width
          : widget.image.height;
      if (minSize < 512) {
        return '<512';
      }
      if (minSize < 768) {
        return '<768';
      }
      if (minSize < 1024) {
        return '<1024';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final String sizeCategory = _getSizeCategory();
    final bool hasPresetRatio = AppConstants.aspectRatioStrings.contains(
      widget.image.aspectRatio,
    );
    final bool hasCaption =
        (widget.image.captions[widget.activeCategory]?.text ?? '')
            .trim()
            .isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        key: ValueKey<String>(widget.image.image.path),
        onTap: () =>
            context.read<ImageListCubit>().onImageSelected(widget.image.id),
        child: ColoredBox(
          color: widget.image.error != null
              ? destructive.withAlpha(20)
              : Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            color: widget.isSelected
                ? panelRaised
                : _isHovered
                ? hoverOverlay
                : Colors.transparent,
            child: Stack(
              children: <Widget>[
                // Terminal marker — the pink edge that says "you are here".
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: 3,
                    color: widget.isSelected ? accentPink : Colors.transparent,
                  ),
                ),
                Row(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: !hasPresetRatio ? destructive : hairline,
                            width: !hasPresetRatio ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(radiusSm),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radiusSm),
                          child: Image.file(
                            key: ValueKey<String>(widget.image.id),
                            widget.image.image,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            cacheWidth: AppConstants.imageListThumbDecodeWidth,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.image.image.path.split('/').last,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: widget.isSelected
                                  ? lightPink
                                  : textPrimary,
                              fontWeight: widget.isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${widget.image.size.readableFileSize}"
                            "${sizeCategory.isEmpty ? '' : ' · $sizeCategory'}",
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isSelected
                                  ? lightPink.withAlpha(160)
                                  : textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!hasCaption)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Tooltip(
                          message: 'No caption',
                          child: Icon(
                            Icons.edit_off,
                            size: 14,
                            color: widget.isSelected
                                ? lightPink.withAlpha(100)
                                : textMuted,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    _RemoveButton(
                      imageId: widget.image.id,
                      isSelected: widget.isSelected,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatefulWidget {
  const _RemoveButton({required this.imageId, required this.isSelected});

  final String imageId;
  final bool isSelected;

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: 'Remove this image and its caption',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final ImageListCubit imageListCubit = context.read<ImageListCubit>();
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Remove Image'),
                  content: const Text(
                    'Are you sure you want to remove this image and its caption?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: destructive),
                      child: const Text('Remove'),
                      onPressed: () {
                        imageListCubit.removeImage(widget.imageId);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
          child: Icon(
            Icons.delete_outline,
            size: 18,
            color: _isHovered
                ? destructive
                : (widget.isSelected ? lightPink.withAlpha(140) : textMuted),
          ),
        ),
      ),
    );
  }
}

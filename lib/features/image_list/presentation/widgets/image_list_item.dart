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

  Color _getBackgroundColor() {
    if (widget.isSelected) {
      return darkGrey;
    }
    if (_isHovered) {
      return Colors.white.withAlpha(20);
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final String sizeCategory = _getSizeCategory();
    final bool hasPresetRatio = AppConstants.aspectRatioStrings.contains(
      widget.image.aspectRatio,
    );

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
          child: ColoredBox(
            color: _getBackgroundColor(),
            child: Stack(
              alignment: Alignment.centerRight,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: !hasPresetRatio
                              ? Border.all(color: destructive, width: 2)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            key: ValueKey<String>(widget.image.id),
                            widget.image.image,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  widget.image.image.path.split('/').last,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: widget.isSelected
                                        ? lightPink
                                        : Colors.white,
                                    fontWeight: widget.isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "(${widget.image.size.readableFileSize})",
                            style: TextStyle(
                              fontSize: 10,
                              color: widget.isSelected
                                  ? lightPink.withAlpha(150)
                                  : Colors.white70,
                              fontWeight: widget.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((widget.image.captions[widget.activeCategory]?.text ?? '')
                        .trim()
                        .isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Tooltip(
                          message: 'No caption',
                          child: Icon(
                            Icons.edit_off,
                            size: 14,
                            color: widget.isSelected
                                ? lightPink.withAlpha(100)
                                : Colors.white.withAlpha(50),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Tooltip(
                      message: 'Remove this image and its caption',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final ImageListCubit imageListCubit = context
                              .read<ImageListCubit>();
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
                                    child: const Text('Remove'),
                                    onPressed: () {
                                      imageListCubit.removeImage(
                                        widget.image.id,
                                      );
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Icon(
                          Icons.delete,
                          size: 18,
                          color: widget.isSelected ? lightPink : Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                if (sizeCategory.isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Text(
                      sizeCategory,
                      style: TextStyle(
                        fontSize: 8,
                        color: widget.isSelected
                            ? lightPink.withAlpha(150)
                            : Colors.white.withAlpha(75),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(color: darkGrey.withAlpha(100), height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

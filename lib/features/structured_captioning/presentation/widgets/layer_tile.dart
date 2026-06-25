import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/bbox_utils.dart';
import 'layer_thumbnail.dart';

/// Data for a single layer tile.
class LayerTileData {
  const LayerTileData({
    required this.index,
    required this.desc,
    required this.type,
    required this.bbox,
    required this.isVisible,
    required this.isSelected,
    required this.title,
  });

  final int index;
  final String desc;
  final String type;
  final List<int>? bbox;
  final bool isVisible;
  final bool isSelected;
  final String title;
}

/// A single row in the layers panel.
class LayerTile extends StatelessWidget {
  const LayerTile({
    required this.data,
    required this.imageFile,
    required this.onTap,
    required this.onToggleVisibility,
    required this.onDuplicate,
    required this.onDelete,
    required this.onEditTitle,
    super.key,
  });

  final LayerTileData data;
  final File imageFile;
  final VoidCallback onTap;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onEditTitle;

  Color get _accent => kBboxColors[data.index % kBboxColors.length];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: data.isSelected
              ? Colors.white.withAlpha(20)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: data.isSelected ? _accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            // Drag handle for reorder (desktop-friendly explicit handle).
            ReorderableDragStartListener(
              index: data.index,
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: Colors.white24,
                ),
              ),
            ),
            // Thumbnail
            if (data.bbox != null)
              LayerThumbnail(
                imageFile: imageFile,
                bbox: data.bbox!,
                cacheKey:
                    '${imageFile.path}_${data.index}_${data.bbox.hashCode}',
                accentColor: _accent,
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  data.type == 'text' ? Icons.text_fields : Icons.crop_square,
                  size: 16,
                  color: _accent,
                ),
              ),
            const SizedBox(width: 8),

            // Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (data.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Row(
                    children: <Widget>[
                      Icon(
                        data.type == 'text'
                            ? Icons.text_fields
                            : Icons.crop_square,
                        size: 12,
                        color: _accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        data.type == 'text' ? 'Text' : 'Object',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: _accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.desc.isEmpty ? 'No description' : data.desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: data.desc.isEmpty
                          ? Colors.white24
                          : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Visibility toggle
            IconButton(
              icon: Icon(
                data.isVisible ? Icons.visibility : Icons.visibility_off,
                size: 14,
                color: data.isVisible ? Colors.white54 : Colors.white24,
              ),
              onPressed: onToggleVisibility,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: data.isVisible ? 'Hide' : 'Show',
            ),

            // Duplicate
            IconButton(
              icon: const Icon(Icons.copy, size: 14, color: Colors.white38),
              onPressed: onDuplicate,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Duplicate',
            ),

            // Edit layer title (UI-only)
            IconButton(
              icon: Icon(
                data.title.isEmpty ? Icons.label_outlined : Icons.label,
                size: 14,
                color: data.title.isEmpty ? Colors.white38 : _accent,
              ),
              onPressed: onEditTitle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: data.title.isEmpty ? 'Add title' : 'Edit title',
            ),

            // Delete
            IconButton(
              icon: const Icon(Icons.close, size: 14, color: Colors.white38),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

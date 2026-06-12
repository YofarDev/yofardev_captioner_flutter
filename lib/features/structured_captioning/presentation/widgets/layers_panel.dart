import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/ideogram_caption.dart';
import '../../logic/structured_editor_cubit.dart';
import 'layer_tile.dart';

/// Layers panel showing all elements with thumbnails.
class LayersPanel extends StatelessWidget {
  const LayersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final StructuredEditorCubit cubit = context
            .read<StructuredEditorCubit>();
        final List<LayerTileData> elements = state
            .caption
            .compositionalDeconstruction
            .elements
            .asMap()
            .entries
            .map((MapEntry<int, IdeogramElement> entry) {
              final int idx = entry.key;
              final IdeogramElement el = entry.value;
              return LayerTileData(
                index: idx,
                desc: el.desc,
                type: el.type,
                bbox: el.bbox,
                isVisible: !state.hiddenElementIndices.contains(idx),
                isSelected: state.selectedElementIndex == idx,
              );
            })
            .toList();

        return ColoredBox(
          color: const Color(0xFF2A2A2A),
          child: Column(
            children: <Widget>[
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: <Widget>[
                    const Text(
                      'Elements',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${elements.length}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Add element',
                      child: InkWell(
                        onTap: () {
                          // Enter bbox drawing mode handled by canvas
                          cubit.addElement();
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.tealAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Element list
              Expanded(
                child: elements.isEmpty
                    ? const Center(
                        child: Text(
                          'No elements',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.white24,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: elements.length,
                        itemBuilder: (BuildContext context, int index) {
                          return LayerTile(
                            data: elements[index],
                            imageFile: state.imageFile,
                            onTap: () => cubit.selectElement(index),
                            onToggleVisibility: () =>
                                cubit.toggleElementVisibility(index),
                            onDelete: () => cubit.removeElement(index),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

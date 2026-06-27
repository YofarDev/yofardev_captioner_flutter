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
                isLocked: state.lockedIndices.contains(idx),
                title: state.elementTitles[idx] ?? '',
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
                    : ReorderableListView.builder(
                        itemCount: elements.length,
                        buildDefaultDragHandles: false,
                        onReorderItem: cubit.moveElement,
                        itemBuilder: (BuildContext context, int index) {
                          final LayerTileData data = elements[index];
                          return LayerTile(
                            key: ValueKey<int>(data.index),
                            data: data,
                            imageFile: state.imageFile,
                            onTap: () => cubit.selectElement(index),
                            onToggleVisibility: () =>
                                cubit.toggleElementVisibility(index),
                            onToggleLock: () =>
                                cubit.toggleElementLock(index),
                            onDuplicate: () => cubit.duplicateElement(index),
                            onDelete: () => cubit.removeElement(index),
                            onEditTitle: () => _editLayerTitle(
                              context,
                              cubit,
                              data.index,
                              data.title,
                            ),
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

Future<void> _editLayerTitle(
  BuildContext context,
  StructuredEditorCubit cubit,
  int index,
  String current,
) async {
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => _LayerTitleEditDialog(initial: current),
  );
  if (result != null) {
    cubit.setElementTitle(index, result);
  }
}

class _LayerTitleEditDialog extends StatefulWidget {
  const _LayerTitleEditDialog({required this.initial});

  final String initial;

  @override
  State<_LayerTitleEditDialog> createState() => _LayerTitleEditDialogState();
}

class _LayerTitleEditDialogState extends State<_LayerTitleEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Layer title'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Shown only in the layers panel',
        ),
        onSubmitted: (String value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/ideogram_caption.dart';
import '../../logic/structured_editor_cubit.dart';
import 'color_palette_editor.dart';

/// Detail editor for the currently selected element.
class ElementDetailSection extends StatelessWidget {
  const ElementDetailSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final StructuredEditorCubit cubit = context
            .read<StructuredEditorCubit>();
        final IdeogramElement? element = state.selectedElement;
        if (element == null) return const SizedBox.shrink();

        final int idx = state.selectedElementIndex!;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lightGrey,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header row: type toggle + delete
              Row(
                children: <Widget>[
                  _TypeToggle(
                    currentType: element.type,
                    onChanged: (String type) => cubit.updateElementType(type),
                  ),
                  const Spacer(),
                  if (element.bbox != null)
                    Tooltip(
                      message: 'Bbox: ${element.bbox}',
                      child: const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.white38,
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: destructive,
                    ),
                    tooltip: 'Delete element',
                    onPressed: () => cubit.removeElement(idx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              _ElementField(
                value: element.desc,
                maxLines: 3,
                onChanged: cubit.updateElementDesc,
              ),
              const SizedBox(height: 10),

              // Text field (only for text type)
              if (element.type == 'text') ...<Widget>[
                const Text(
                  'Text Content',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 4),
                _ElementField(
                  value: element.text ?? '',
                  maxLines: null,
                  minLines: 2,
                  onChanged: (String v) =>
                      cubit.updateElementText(v.isEmpty ? null : v),
                ),
                const SizedBox(height: 10),
              ],

              // Color palette
              const Text(
                'Color Palette',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              ColorPaletteEditor(
                colors: element.colorPalette ?? <String>[],
                onChanged: cubit.updateElementColorPalette,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.currentType, required this.onChanged});

  final String currentType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: currentType == 'text'
            ? Colors.amber.withAlpha(40)
            : Colors.teal.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _TypeChip(
            label: 'Object',
            active: currentType == 'obj',
            onTap: () => onChanged('obj'),
          ),
          _TypeChip(
            label: 'Text',
            active: currentType == 'text',
            onTap: () => onChanged('text'),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _ElementField extends StatefulWidget {
  const _ElementField({
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
  });

  final String value;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String> onChanged;

  @override
  State<_ElementField> createState() => _ElementFieldState();
}

class _ElementFieldState extends State<_ElementField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ElementField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      final int selEnd = _controller.selection.baseOffset;
      _controller.text = widget.value;
      final int pos = selEnd.clamp(0, widget.value.length);
      _controller.selection = TextSelection.collapsed(offset: pos);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF333333),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      onChanged: widget.onChanged,
    );
  }
}

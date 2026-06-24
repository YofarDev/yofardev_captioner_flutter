import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/data/models/llm_provider_type.dart';
import '../../../llm_config/logic/llm_configs_cubit.dart';
import '../../data/models/ideogram_caption.dart';
import '../../logic/structured_editor_cubit.dart';
import '../utils/bbox_utils.dart';
import 'color_palette_editor.dart';
import 'recaption_element_dialog.dart';

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

        final bool anyRecaptioning = state.recaptioningElementIndex != null;

        // Match the card to the selected layer's bbox color.
        final Color layerColor = kBboxColors[idx % kBboxColors.length];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: layerColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: layerColor.withValues(alpha: 0.8)),
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
                    onPressed: anyRecaptioning
                        ? null
                        : () => cubit.removeElement(idx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              const Text(
                'Position',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              _BboxFields(
                bbox: element.bbox,
                onChanged: cubit.updateElementBbox,
              ),
              const SizedBox(height: 10),

              _RecaptionButton(elementIndex: idx, element: element),
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
                enabled: !anyRecaptioning,
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
                  enabled: !anyRecaptioning,
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
                imageFile: state.imageFile,
                elementBbox: element.bbox,
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
    this.enabled = true,
  });

  final String value;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String> onChanged;
  final bool enabled;

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
      enabled: widget.enabled,
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

/// Resolves the active [LlmConfig], subscribing to [LlmConfigsCubit] so the
/// button rebuilds when the user switches config. Returns null when no
/// [LlmConfigsCubit] is present in the tree (defensive for tests).
LlmConfig? _maybeWatchSelectedConfig(BuildContext context) {
  try {
    return context.watch<LlmConfigsCubit>().state.llmConfigs.selectedConfig;
  } on ProviderNotFoundException {
    return null;
  }
}

class _RecaptionButton extends StatelessWidget {
  const _RecaptionButton({required this.elementIndex, required this.element});

  final int elementIndex;
  final IdeogramElement element;

  @override
  Widget build(BuildContext context) {
    final StructuredEditorCubit cubit = context.read<StructuredEditorCubit>();

    // Resolve the active config safely. Returns null when no LlmConfigsCubit
    // ancestor exists (defensive; the app provides one at the root).
    final LlmConfig? config = _maybeWatchSelectedConfig(context);

    final bool isLocalMlx = config?.providerType == LlmProviderType.localMlx;
    final bool canRecaption =
        config != null && !isLocalMlx && element.bbox != null;

    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      buildWhen: (StructuredEditorState prev, StructuredEditorState next) =>
          prev.recaptioningElementIndex != next.recaptioningElementIndex ||
          prev.status != next.status ||
          prev.error != next.error,
      builder: (BuildContext context, StructuredEditorState state) {
        final bool isBusy = state.recaptioningElementIndex == elementIndex;
        final String? error = state.status == StructuredEditorStatus.error
            ? state.error
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FilledButton.icon(
              key: const Key('recaptionButton'),
              onPressed: (isBusy || !canRecaption)
                  ? null
                  : () => _onRecaption(context, cubit, config),
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(isBusy ? 'Recaptioning…' : 'Recaption'),
            ),
            if (element.bbox == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Draw a bbox to enable recaption.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              )
            else if (config == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Select a remote VLM config to enable recaption.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              )
            else if (isLocalMlx)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Local MLX configs are not supported for recaption.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: const TextStyle(color: destructive, fontSize: 11),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _onRecaption(
    BuildContext context,
    StructuredEditorCubit cubit,
    LlmConfig config,
  ) async {
    final String? instructions = await showRecaptionElementDialog(context);
    if (instructions == null) return; // user cancelled
    await cubit.recaptionSelectedElement(
      config: config,
      instructions: instructions,
    );
  }
}

/// Compact x, y, w, h editor for an element bbox in 0–1000 normalized space.
/// A null [bbox] seeds zeros so a brand-new element can be positioned by typing.
class _BboxFields extends StatefulWidget {
  const _BboxFields({required this.bbox, required this.onChanged});

  final List<int>? bbox; // [y1, x1, y2, x2], null = no bbox yet
  final ValueChanged<List<int>> onChanged;

  @override
  State<_BboxFields> createState() => _BboxFieldsState();
}

class _BboxFieldsState extends State<_BboxFields> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = _values()
        .map((int v) => TextEditingController(text: '$v'))
        .toList(growable: false);
  }

  List<int> _values() {
    final List<int> b = widget.bbox ?? <int>[0, 0, 0, 0];
    return <int>[b[1], b[0], b[3] - b[1], b[2] - b[0]];
  }

  @override
  void didUpdateWidget(covariant _BboxFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bbox == oldWidget.bbox) return;
    final List<int> v = _values();
    for (int i = 0; i < 4; i++) {
      final String expected = '${v[i]}';
      if (_controllers[i].text != expected) {
        _controllers[i].text = expected;
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _commit() {
    int? p(int i) => int.tryParse(_controllers[i].text);
    final int? x = p(0);
    final int? y = p(1);
    final int? w = p(2);
    final int? h = p(3);
    if (x == null || y == null || w == null || h == null) return;
    final int x1 = x.clamp(0, 1000);
    final int y1 = y.clamp(0, 1000);
    final int x2 = (x + w).clamp(0, 1000);
    final int y2 = (y + h).clamp(0, 1000);
    widget.onChanged(<int>[y1, x1, y2, x2]);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _CompactNumField(
              label: const <String>['x', 'y', 'w', 'h'][i],
              controller: _controllers[i],
              onChanged: (_) => _commit(),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactNumField extends StatelessWidget {
  const _CompactNumField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          prefixText: '$label ',
          prefixStyle: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
          filled: true,
          fillColor: const Color(0xFF333333),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

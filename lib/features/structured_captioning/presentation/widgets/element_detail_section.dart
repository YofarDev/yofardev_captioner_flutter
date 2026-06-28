import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/logic/llm_configs_cubit.dart';
import '../../data/models/ideogram_caption.dart';
import '../../data/services/color_extraction_service.dart';
import '../../logic/structured_editor_cubit.dart';
import '../utils/bbox_utils.dart';
import 'color_palette_editor.dart';
import 'editor_primitives.dart';
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
            color: layerColor.withValues(alpha: 0.16),
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
                        color: textMuted,
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
              const SizedBox(height: 12),

              const FieldLabel('Position'),
              const SizedBox(height: 4),
              _BboxFields(
                bbox: element.bbox,
                onChanged: cubit.updateElementBbox,
              ),
              const SizedBox(height: 10),

              _RecaptionButton(elementIndex: idx, element: element),
              const SizedBox(height: 10),

              // Description
              const FieldLabel('Description'),
              const SizedBox(height: 4),
              EditorTextField(
                value: element.desc,
                maxLines: 3,
                enabled: !anyRecaptioning,
                onChanged: cubit.updateElementDesc,
              ),
              const SizedBox(height: 10),

              // Text field (only for text type)
              if (element.type == 'text') ...<Widget>[
                const FieldLabel('Text Content'),
                const SizedBox(height: 4),
                EditorTextField(
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
              Row(
                children: <Widget>[
                  const FieldLabel('Color Palette'),
                  const Spacer(),
                  if (element.bbox != null)
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: accentPink,
                        ),
                        tooltip: 'Extract colors from region',
                        onPressed: () async {
                          final List<String> palette =
                              await ColorExtractionService()
                                  .extractPaletteFromRegion(
                            state.imageFile,
                            element.bbox!,
                          );
                          if (palette.isNotEmpty) {
                            cubit.updateElementColorPalette(palette);
                          }
                        },
                      ),
                    ),
                ],
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
    final Color tint = currentType == 'text' ? amberWarn : accentPink;
    return Container(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
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
          color: active
              ? textPrimary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? textPrimary : textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RecaptionButton extends StatefulWidget {
  const _RecaptionButton({required this.elementIndex, required this.element});

  final int elementIndex;
  final IdeogramElement element;

  @override
  State<_RecaptionButton> createState() => _RecaptionButtonState();
}

class _RecaptionButtonState extends State<_RecaptionButton> {
  String? _selectedConfigId;
  bool _cropToBbox = false;

  @override
  void initState() {
    super.initState();
    _initConfigFromGlobal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedConfigId == null) _initConfigFromGlobal();
  }

  void _initConfigFromGlobal() {
    try {
      final String? globalId = context
          .read<LlmConfigsCubit>()
          .state
          .llmConfigs
          .selectedConfigId;
      if (globalId != null) _selectedConfigId = globalId;
    } on ProviderNotFoundException {
      // no-op
    }
  }

  List<LlmConfig> _usableConfigs(LlmConfigsState llmState) {
    return llmState.llmConfigs.configs;
  }

  @override
  Widget build(BuildContext context) {
    final StructuredEditorCubit cubit = context.read<StructuredEditorCubit>();

    // Watch for config additions/removals so the dropdown stays current.
    final LlmConfigsState llmState;
    try {
      llmState = context.watch<LlmConfigsCubit>().state;
    } on ProviderNotFoundException {
      // Defensive: no [LlmConfigsCubit] ancestor (tests).
      return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
        buildWhen: (_, StructuredEditorState next) =>
            next.recaptioningElementIndex != null ||
            next.status == StructuredEditorStatus.error,
        builder: (_, StructuredEditorState _) => const SizedBox.shrink(),
      );
    }

    final List<LlmConfig> configs = _usableConfigs(llmState);
    final String? effectiveId = _selectedConfigId != null &&
            configs.any((LlmConfig c) => c.id == _selectedConfigId)
        ? _selectedConfigId
        : (configs.isNotEmpty ? configs.first.id : null);
    final LlmConfig? config = effectiveId != null
        ? configs.cast<LlmConfig?>().firstWhere(
              (LlmConfig? c) => c?.id == effectiveId,
              orElse: () => null,
            )
        : null;

    final bool canRecaption = config != null && widget.element.bbox != null;

    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      buildWhen: (StructuredEditorState prev, StructuredEditorState next) =>
          prev.recaptioningElementIndex != next.recaptioningElementIndex ||
          prev.status != next.status ||
          prev.error != next.error,
      builder: (BuildContext context, StructuredEditorState state) {
        final bool isBusy =
            state.recaptioningElementIndex == widget.elementIndex;
        final String? error = state.status == StructuredEditorStatus.error
            ? state.error
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
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
                ),
                if (configs.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: effectiveId,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 13,
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    dropdownColor: panelRaised,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: textSecondary,
                    ),
                    underline: const SizedBox.shrink(),
                    onChanged: (String? id) {
                      if (id != null) setState(() => _selectedConfigId = id);
                    },
                    items: configs.map<DropdownMenuItem<String>>((
                      LlmConfig c,
                    ) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(c.name),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
            if (config != null && widget.element.bbox != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: <Widget>[
                    _ChipToggle(
                      label: 'Full',
                      selected: !_cropToBbox,
                      onTap: () => setState(() => _cropToBbox = false),
                    ),
                    const SizedBox(width: 6),
                    _ChipToggle(
                      label: 'Crop',
                      selected: _cropToBbox,
                      onTap: () => setState(() => _cropToBbox = true),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _cropToBbox ? 'crop to bbox' : 'full image',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.element.bbox == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Draw a bbox to enable recaption.',
                  style: TextStyle(color: textMuted, fontSize: 11),
                ),
              )
            else if (configs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Add a VLM config to enable recaption.',
                  style: TextStyle(color: textMuted, fontSize: 11),
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
    if (instructions == null) return;
    await cubit.recaptionSelectedElement(
      config: config,
      instructions: instructions,
      cropToBbox: _cropToBbox,
    );
  }
}

class _ChipToggle extends StatelessWidget {
  const _ChipToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? accentPink.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? accentPink : hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? lightPink : textSecondary,
          ),
        ),
      ),
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
          color: textPrimary,
        ),
        decoration: InputDecoration(
          prefixText: '$label ',
          prefixStyle: const TextStyle(color: textMuted, fontSize: 11),
          filled: true,
          fillColor: panelRaised,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

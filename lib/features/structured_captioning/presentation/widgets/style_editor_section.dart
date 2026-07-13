import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/logic/llm_configs_cubit.dart';
import '../../data/services/color_extraction_service.dart';
import '../../logic/structured_editor_cubit.dart';
import 'color_palette_editor.dart';
import 'editor_primitives.dart';

/// Editable fields for [IdeogramStyleDescription].
///
/// Renders only the fields — the owning panel provides the "Style" header so
/// every section shares the same rhythm.
class StyleEditorSection extends StatelessWidget {
  const StyleEditorSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final StructuredEditorCubit cubit = context
            .read<StructuredEditorCubit>();
        final bool isPhoto =
            state.caption.styleDescription.medium == 'photograph';
        final bool busy = state.recaptioningStyle;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SectionLabel('Style'),
                const Spacer(),
                _StyleRecaptionButton(),
              ],
            ),
            const SizedBox(height: 8),
            LabeledFieldRow(
              label: 'Medium',
              child: EditorTextField(
                value: state.caption.styleDescription.medium,
                dense: true,
                enabled: !busy,
                onChanged: cubit.updateMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (isPhoto)
              LabeledFieldRow(
                label: 'Camera',
                child: EditorTextField(
                  value: state.caption.styleDescription.photo ?? '',
                  dense: true,
                  enabled: !busy,
                  onChanged: (String v) =>
                      cubit.updatePhoto(v.isEmpty ? null : v),
                ),
              )
            else
              LabeledFieldRow(
                label: 'Art Style',
                child: EditorTextField(
                  value: state.caption.styleDescription.artStyle ?? '',
                  dense: true,
                  enabled: !busy,
                  onChanged: (String v) =>
                      cubit.updateArtStyle(v.isEmpty ? null : v),
                ),
              ),
            const SizedBox(height: 8),
            LabeledFieldRow(
              label: 'Aesthetics',
              child: EditorTextField(
                value: state.caption.styleDescription.aesthetics,
                dense: true,
                enabled: !busy,
                onChanged: cubit.updateAesthetics,
              ),
            ),
            const SizedBox(height: 8),
            LabeledFieldRow(
              label: 'Lighting',
              child: EditorTextField(
                value: state.caption.styleDescription.lighting,
                dense: true,
                enabled: !busy,
                onChanged: cubit.updateLighting,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const SectionLabel('Color Palette'),
                const Spacer(),
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
                    tooltip: 'Extract colors from image',
                    onPressed: () async {
                      final List<String> palette =
                          await ColorExtractionService().extractPalette(
                            state.imageFile,
                          );
                      if (palette.isNotEmpty) {
                        cubit.updateStyleColorPalette(palette);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ColorPaletteEditor(
              colors: state.caption.styleDescription.colorPalette,
              onChanged: cubit.updateStyleColorPalette,
              imageFile: state.imageFile,
            ),
          ],
        );
      },
    );
  }
}

/// Compact regenerate button + model dropdown for whole-style recaption.
///
/// Mirrors the per-element `_RecaptionButton` config-selection logic: defaults
/// to the global `selectedConfigId`, persists its own override, and watches
/// [LlmConfigsCubit] so the dropdown stays current.
class _StyleRecaptionButton extends StatefulWidget {
  @override
  State<_StyleRecaptionButton> createState() => _StyleRecaptchaButtonState();
}

class _StyleRecaptchaButtonState extends State<_StyleRecaptionButton> {
  String? _selectedConfigId;

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

  @override
  Widget build(BuildContext context) {
    final StructuredEditorCubit cubit = context.read<StructuredEditorCubit>();

    final LlmConfigsState llmState;
    try {
      llmState = context.watch<LlmConfigsCubit>().state;
    } on ProviderNotFoundException {
      // Defensive: no [LlmConfigsCubit] ancestor (tests).
      return const SizedBox.shrink();
    }

    final List<LlmConfig> configs = llmState.llmConfigs.configs;
    final String? effectiveId =
        _selectedConfigId != null &&
            configs.any((LlmConfig c) => c.id == _selectedConfigId)
        ? _selectedConfigId
        : (configs.isNotEmpty ? configs.first.id : null);
    final LlmConfig? config = effectiveId != null
        ? configs.cast<LlmConfig?>().firstWhere(
            (LlmConfig? c) => c?.id == effectiveId,
            orElse: () => null,
          )
        : null;

    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      buildWhen: (StructuredEditorState prev, StructuredEditorState next) =>
          prev.recaptioningStyle != next.recaptioningStyle ||
          prev.status != next.status ||
          prev.error != next.error,
      builder: (BuildContext context, StructuredEditorState state) {
        final bool isBusy = state.recaptioningStyle;
        final String? error = state.status == StructuredEditorStatus.error
            ? state.error
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 24,
                  width: 24,
                  child: IconButton(
                    key: const Key('styleRecaptionButton'),
                    padding: EdgeInsets.zero,
                    icon: isBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentPink,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: accentPink,
                          ),
                    tooltip: 'Regenerate style fields via VLM',
                    onPressed: (isBusy || config == null)
                        ? null
                        : () => cubit.recaptionStyle(config: config),
                  ),
                ),
                if (configs.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: effectiveId,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 12,
                      color: textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    dropdownColor: panelRaised,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: textSecondary,
                      size: 18,
                    ),
                    underline: const SizedBox.shrink(),
                    onChanged: isBusy
                        ? null
                        : (String? id) {
                            if (id != null) {
                              setState(() => _selectedConfigId = id);
                            }
                          },
                    items: configs.map<DropdownMenuItem<String>>((LlmConfig c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(c.name),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
            if (config == null)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Add a VLM config to enable style regen.',
                  style: TextStyle(color: textMuted, fontSize: 10),
                ),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  error,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: destructive, fontSize: 10),
                ),
              ),
          ],
        );
      },
    );
  }
}

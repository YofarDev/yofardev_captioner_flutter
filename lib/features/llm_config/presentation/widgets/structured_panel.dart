import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/structured_batch_overrides.dart';
import '../../logic/llm_configs_cubit.dart';

/// Tab body: the structured captioning pipeline.
///
/// Single scrollable column. Ideogram JSON is the master gate; when it is off
/// the downstream cards collapse into an explicit locked teaser instead of the
/// old opacity + AbsorbPointer hack.
class StructuredPanel extends StatelessWidget {
  const StructuredPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
      builder: (BuildContext context, LlmConfigsState state) {
        final bool ideogramOn = state.llmConfigs.ideogramJsonEnabled;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          children: <Widget>[
            const _PipelineIntro(),
            const SizedBox(height: 20),
            _MasterHeroCard(
              enabled: ideogramOn,
              onChanged: (bool v) =>
                  context.read<LlmConfigsCubit>().setIdeogramJsonEnabled(v),
            ),
            const SizedBox(height: 16),
            if (!ideogramOn) ...<Widget>[
              const _LockedTeaser(),
            ] else ...<Widget>[
              _ToggleCard(
                accentColor: Colors.amber[300]!,
                icon: Icons.bug_report_outlined,
                title: 'Debug Mode',
                subtitle:
                    'Save prompt, raw VLM response and bbox overlay image alongside each image.',
                value: state.llmConfigs.debugMode,
                onChanged: (bool v) =>
                    context.read<LlmConfigsCubit>().setDebugMode(v),
              ),
              const SizedBox(height: 16),
              _ToggleCard(
                accentColor: Colors.deepOrange[300]!,
                icon: Icons.layers_clear_outlined,
                title: 'Disable SAM',
                subtitle:
                    'Skip SAM detection and use VLM bounding boxes directly.',
                value: state.llmConfigs.disableSam,
                onChanged: (bool v) =>
                    context.read<LlmConfigsCubit>().setDisableSam(v),
              ),
              const SizedBox(height: 16),
              _OverridesCard(
                overrides: state.llmConfigs.structuredBatchOverrides,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PipelineIntro extends StatelessWidget {
  const _PipelineIntro();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '03',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: lightPink,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'STRUCTURED CAPTIONS',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'VLM + SAM3 pipeline producing structured bounding-box output. '
                'Toggle the master switch to expose batch overrides and debug artifacts.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MasterHeroCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _MasterHeroCard({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: enabled ? pinkSurface : panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? lightPink.withValues(alpha: 0.6) : hairline,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lightPink.withValues(alpha: enabled ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.data_object,
              color: enabled ? lightPink : pinkDim,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Ideogram JSON Caption',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled
                      ? 'Structured pipeline active'
                      : 'Structured pipeline inactive',
                  style: TextStyle(
                    color: enabled ? lightPink : textMuted,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          _PinkSwitch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LockedTeaser extends StatelessWidget {
  const _LockedTeaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: panelDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hairline),
      ),
      child: const Column(
        children: <Widget>[
          Icon(Icons.lock_outline, size: 26, color: pinkDim),
          SizedBox(height: 12),
          Text(
            'Debug & batch overrides are locked',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Enable Ideogram JSON Caption above to configure the pipeline.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hairline),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          _PinkSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _OverridesCard extends StatelessWidget {
  final StructuredBatchOverrides overrides;

  const _OverridesCard({required this.overrides});

  void _update(BuildContext context, StructuredBatchOverrides next) {
    context.read<LlmConfigsCubit>().updateStructuredBatchOverrides(next);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = overrides.enabled;
    return Container(
      decoration: BoxDecoration(
        color: panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? lightPink.withValues(alpha: 0.4) : hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Master toggle row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: <Widget>[
                const Icon(Icons.tune, color: lightPink, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Structured Batch Overrides',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Override VLM fields for all images in a batch.',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                _PinkSwitch(
                  value: enabled,
                  onChanged: (bool v) =>
                      _update(context, overrides.copyWith(enabled: v)),
                ),
              ],
            ),
          ),
          if (enabled) ...<Widget>[
            const Divider(height: 1, thickness: 1, color: hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    "Enabled fields replace the VLM's own value for "
                    'every image in this batch.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Style — unified toggle with photo/art-style chips + fields
                  _OverrideRow(
                    accentColor: lightPink,
                    icon: Icons.brush_outlined,
                    label: 'Style',
                    enabled: overrides.styleMode != null,
                    onToggle: (bool v) => _update(
                      context,
                      overrides.copyWith(
                        styleMode: v ? 'photo' : null,
                        clearStyleMode: !v,
                        clearStyleDetail: !v,
                        overrideMedium: v,
                        medium: v ? 'photograph' : null,
                        clearMedium: !v,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            _ChoiceChip(
                              label: 'Photo',
                              selected: overrides.styleMode == 'photo',
                              onSelected: (bool v) => _update(
                                context,
                                overrides.copyWith(
                                  styleMode: v ? 'photo' : null,
                                  clearStyleMode: !v,
                                  overrideMedium: v,
                                  medium: v ? 'photograph' : null,
                                  clearMedium: !v,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ChoiceChip(
                              label: 'Art Style',
                              selected: overrides.styleMode == 'art_style',
                              onSelected: (bool v) => _update(
                                context,
                                overrides.copyWith(
                                  styleMode: v ? 'art_style' : null,
                                  clearStyleMode: !v,
                                  overrideMedium: false,
                                  clearMedium: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _LabeledField(
                          hint: overrides.styleMode == 'photo'
                              ? 'Camera, lens, depth-of-field details'
                              : 'Art style description',
                          value: overrides.styleDetail,
                          onChanged: (String v) => _update(
                            context,
                            overrides.copyWith(
                              styleDetail: v.isEmpty ? null : v,
                              clearStyleDetail: v.isEmpty,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _LabeledField(
                          label: 'Medium',
                          hint: overrides.styleMode == 'photo'
                              ? 'e.g. photograph, film, digital...'
                              : 'e.g. illustration, painting, graphic_design, 3d_render...',
                          value: overrides.medium,
                          onChanged: (String v) => _update(
                            context,
                            overrides.copyWith(
                              medium: v.isEmpty ? null : v,
                              clearMedium: v.isEmpty,
                              overrideMedium: v.isNotEmpty,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _OverrideRow(
                    accentColor: Colors.teal[300]!,
                    icon: Icons.palette_outlined,
                    label: 'Aesthetics',
                    enabled: overrides.overrideAesthetics,
                    onToggle: (bool v) => _update(
                      context,
                      overrides.copyWith(overrideAesthetics: v),
                    ),
                    child: _LabeledField(
                      hint: '3 adjectives describing visual feel',
                      value: overrides.aesthetics,
                      onChanged: (String v) => _update(
                        context,
                        overrides.copyWith(
                          aesthetics: v.isEmpty ? null : v,
                          clearAesthetics: v.isEmpty,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _OverrideRow(
                    accentColor: Colors.orange[300]!,
                    icon: Icons.light_mode_outlined,
                    label: 'Lighting',
                    enabled: overrides.overrideLighting,
                    onToggle: (bool v) => _update(
                      context,
                      overrides.copyWith(overrideLighting: v),
                    ),
                    child: _LabeledField(
                      hint: 'Lighting description',
                      value: overrides.lighting,
                      onChanged: (String v) => _update(
                        context,
                        overrides.copyWith(
                          lighting: v.isEmpty ? null : v,
                          clearLighting: v.isEmpty,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _OverrideRow(
                    accentColor: Colors.purple[300]!,
                    icon: Icons.wallpaper_outlined,
                    label: 'Background',
                    enabled: overrides.overrideBackground,
                    onToggle: (bool v) => _update(
                      context,
                      overrides.copyWith(overrideBackground: v),
                    ),
                    child: _LabeledField(
                      hint: 'Background description',
                      value: overrides.background,
                      maxLines: 3,
                      onChanged: (String v) => _update(
                        context,
                        overrides.copyWith(
                          background: v.isEmpty ? null : v,
                          clearBackground: v.isEmpty,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverrideRow extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final Widget child;

  const _OverrideRow({
    required this.accentColor,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: panelRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? lightPink.withValues(alpha: 0.4) : hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
              ),
              _PinkSwitch(value: enabled, onChanged: onToggle),
            ],
          ),
          if (enabled) ...<Widget>[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String? label;
  final String hint;
  final String? value;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _LabeledField({
    this.label,
    required this.hint,
    this.value,
    this.maxLines = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 5),
        ],
        _OverrideField(
          value: value,
          hint: hint,
          maxLines: maxLines,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Holds its own controller (created in initState, synced via
/// didUpdateWidget) so we never rebuild a TextEditingController inline.
class _OverrideField extends StatefulWidget {
  final String? value;
  final String hint;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _OverrideField({
    required this.value,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  State<_OverrideField> createState() => _OverrideFieldState();
}

class _OverrideFieldState extends State<_OverrideField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant _OverrideField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String next = widget.value ?? '';
    if (_controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
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
      style: const TextStyle(fontSize: 14, color: textPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: panelDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: lightPink.withValues(alpha: 0.7)),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: lightPink,
      backgroundColor: panelDark,
      side: BorderSide(color: selected ? lightPink : hairline),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? darkGrey : textSecondary,
      ),
    );
  }
}

class _PinkSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PinkSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: lightPink,
      activeTrackColor: lightPink.withValues(alpha: 0.35),
      inactiveThumbColor: textSecondary,
      inactiveTrackColor: hairline,
      trackOutlineColor: WidgetStateProperty.all<Color>(Colors.transparent),
    );
  }
}

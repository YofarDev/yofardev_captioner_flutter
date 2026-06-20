import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_operations/presentation/widgets/controls_widgets.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/logic/llm_configs_cubit.dart';
import '../../../llm_config/presentation/pages/llm_config_widget.dart';
import '../../../structured_captioning/data/models/ideogram_caption.dart';
import '../../../structured_captioning/logic/structured_captioning_cubit.dart';
import '../../data/models/batch_apply_template.dart';
import '../../data/models/caption_options.dart';
import '../../logic/batch_apply/batch_json_apply_cubit.dart';
import '../../logic/batch_apply/batch_json_apply_state.dart';
import '../../logic/captioning_cubit.dart';
import '../widgets/batch_json_apply_dialog.dart';

class CaptionControls extends StatefulWidget {
  const CaptionControls({super.key});

  @override
  State<CaptionControls> createState() => _CaptionControlsState();
}

class _CaptionControlsState extends State<CaptionControls> {
  CaptionOptions _selectedOption = CaptionOptions.values.first;
  bool _scopeToFiltered = false;

  @override
  Widget build(BuildContext context) {
    final ImageListState imageState = context.read<ImageListCubit>().state;
    final int totalImages = imageState.images.length;

    return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
      builder: (BuildContext context, LlmConfigsState configState) {
        final bool ideogramMode = configState.llmConfigs.ideogramJsonEnabled;
        final int missingCount = imageState.images.where((AppImage img) {
          final String text =
              img.captions[imageState.activeCategory]?.text ?? '';
          if (ideogramMode) {
            return text.isEmpty ||
                !IdeogramCaption.isIdeogramJson(text) ||
                IdeogramCaption.hasEmptyHighLevelDescription(text);
          }
          return text.isEmpty;
        }).length;

        return RadioGroup<CaptionOptions>(
          groupValue: _selectedOption,
          onChanged: (CaptionOptions? value) {
            setState(() {
              _selectedOption = value!;
            });
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SettingsButton(),
                  const LlmConfigWidget(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            "Caption: ",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildRadioButton(
                            label: 'This image',
                            option: CaptionOptions.current,
                          ),
                          const SizedBox(width: 12),
                          _buildRadioButton(
                            label: 'Missing captions ($missingCount)',
                            option: CaptionOptions.missing,
                          ),
                          const SizedBox(width: 12),
                          _buildRadioButton(
                            label: 'All ($totalImages)',
                            option: CaptionOptions.all,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildRunButton(count: totalImages),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadioButton({
    required String label,
    required CaptionOptions option,
  }) {
    final bool isSelected = _selectedOption == option;
    return InkWell(
      onTap: () => setState(() => _selectedOption = option),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? lightPink.withAlpha(80)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? lightPink.withAlpha(150)
                : Colors.white.withAlpha(30),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Transform.scale(
              scale: 0.8,
              child: Radio<CaptionOptions>(
                value: option,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                fillColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return lightPink;
                  }
                  return Colors.grey;
                }),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeToFilteredCheckbox(ImageListState imageState) {
    final bool hasActiveSearch = imageState.searchQuery.isNotEmpty;
    if (!hasActiveSearch) {
      return const SizedBox.shrink();
    }
    final ImageListCubit cubit = context.read<ImageListCubit>();
    final int filteredCount = cubit.filteredImages.length;
    final bool disabledForCurrent = _selectedOption == CaptionOptions.current;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Opacity(
        opacity: disabledForCurrent ? 0.4 : 1.0,
        child: AbsorbPointer(
          absorbing: disabledForCurrent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(unselectedWidgetColor: lightPink.withAlpha(120)),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _scopeToFiltered,
                    onChanged: (bool? value) {
                      setState(() {
                        _scopeToFiltered = value ?? false;
                      });
                    },
                    activeColor: lightPink,
                    checkColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Limit to search results ($filteredCount)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withAlpha(220),
                  decoration: disabledForCurrent
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunButton({
    required int count,
  }) => BlocBuilder<ImageListCubit, ImageListState>(
    builder: (BuildContext context, ImageListState imageListState) {
      return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
        builder: (BuildContext context, LlmConfigsState configState) {
          final bool ideogramMode = configState.llmConfigs.ideogramJsonEnabled;

          if (ideogramMode) {
            return BlocBuilder<
              StructuredCaptioningCubit,
              StructuredCaptioningState
            >(
              builder:
                  (
                    BuildContext context,
                    StructuredCaptioningState structuredState,
                  ) {
                    return _buildRunRow(
                      context: context,
                      imageListState: imageListState,
                      configState: configState,
                      isInProgress:
                          structuredState.status ==
                          StructuredCaptioningStatus.inProgress,
                      processedImages: structuredState.processedImages,
                      totalImages: structuredState.totalImages,
                      isCancelling: structuredState.isCancelling,
                      stepLabel: structuredState.stepLabel,
                      error: structuredState.error,
                      isIdeogram: true,
                      imageCount: count,
                    );
                  },
            );
          }

          return BlocBuilder<CaptioningCubit, CaptioningState>(
            builder: (BuildContext context, CaptioningState captioningState) {
              return _buildRunRow(
                context: context,
                imageListState: imageListState,
                configState: configState,
                isInProgress:
                    captioningState.status == CaptioningStatus.inProgress,
                processedImages: captioningState.processedImages,
                totalImages: captioningState.totalImages,
                isCancelling: captioningState.isCancelling,
                stepLabel: null,
                error: captioningState.error,
                isIdeogram: false,
                imageCount: count,
              );
            },
          );
        },
      );
    },
  );

  Widget _buildRunRow({
    required BuildContext context,
    required ImageListState imageListState,
    required LlmConfigsState configState,
    required bool isInProgress,
    required int processedImages,
    required int totalImages,
    required bool isCancelling,
    required String? stepLabel,
    required String? error,
    required bool isIdeogram,
    required int imageCount,
  }) {
    final Color accentColor = isIdeogram
        ? Colors.teal.withAlpha(220)
        : lightPink.withAlpha(220);
    final Color progressBg = isIdeogram
        ? Colors.teal.withAlpha(100)
        : Colors.green.withAlpha(100);
    final Color progressFg = isIdeogram ? Colors.teal : Colors.green;
    final bool scoped =
        _scopeToFiltered && imageListState.searchQuery.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (imageListState.searchQuery.isNotEmpty) ...<Widget>[
          _buildScopeToFilteredCheckbox(imageListState),
          const SizedBox(width: 12),
        ],
        GestureDetector(
          onSecondaryTap: () {
            if (!isInProgress) {
              context.read<LlmConfigsCubit>().setIdeogramJsonEnabled(
                !isIdeogram,
              );
            }
          },
          child: Tooltip(
            message: isIdeogram
                ? 'Run AI structured captioning (right-click to toggle mode)'
                : 'Run AI caption generation (right-click to toggle mode)',
            child: AppButton(
              text: isIdeogram ? "▶  JSON Run" : "▶  Run",
              isLoading: isInProgress,
              backgroundColor: accentColor,
              onTap:
                  imageListState.images.isNotEmpty &&
                      configState.llmConfigs.selectedConfigId != null &&
                      !isInProgress
                  ? () {
                      final LlmConfig llm = configState.llmConfigs.configs
                          .firstWhere(
                            (LlmConfig c) =>
                                c.id == configState.llmConfigs.selectedConfigId,
                          );
                      if (isIdeogram) {
                        context
                            .read<StructuredCaptioningCubit>()
                            .runStructuredCaptioner(
                              llm: llm,
                              option: _selectedOption,
                              overrides:
                                  configState
                                      .llmConfigs
                                      .structuredBatchOverrides
                                      .enabled
                                  ? configState
                                        .llmConfigs
                                        .structuredBatchOverrides
                                  : null,
                              debugMode: configState.llmConfigs.debugMode,
                              disableSam: configState.llmConfigs.disableSam,
                              scopeToFiltered: scoped,
                            );
                      } else {
                        context.read<CaptioningCubit>().runCaptioner(
                          llm: llm,
                          prompt: configState.llmConfigs.selectedPrompt!,
                          option: _selectedOption,
                          scopeToFiltered: scoped,
                        );
                      }
                    }
                  : null,
            ),
          ),
        ),
        if (isIdeogram) const SizedBox(width: 8),
        if (isIdeogram)
          _buildBatchApplyButton(context, configState, imageCount),
        if (isInProgress) ...<Widget>[
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: progressBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (stepLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      stepLabel,
                      style: TextStyle(
                        color: isIdeogram ? Colors.tealAccent : Colors.green,
                        fontSize: 11,
                      ),
                    ),
                  ),
                Text(
                  '$processedImages/$totalImages',
                  style: TextStyle(
                    color: progressFg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isCancelling) ...<Widget>[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StopButton(
            isCancelling: isCancelling,
            onTap: () {
              if (isIdeogram) {
                context
                    .read<StructuredCaptioningCubit>()
                    .cancelStructuredCaptioning();
              } else {
                context.read<CaptioningCubit>().cancelCaptioning();
              }
            },
          ),
        ],
        if (error != null && error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Tooltip(
              message: error,
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: error));
                  NotificationOverlay.show(
                    context,
                    message: 'Error copied to clipboard',
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: destructive.withAlpha(100),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: destructive,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBatchApplyButton(
    BuildContext context,
    LlmConfigsState configState,
    int imageCount,
  ) {
    return BlocBuilder<BatchJsonApplyCubit, BatchJsonApplyState>(
      builder: (BuildContext context, BatchJsonApplyState state) {
        final bool isInProgress = state is BatchJsonApplyInProgress;
        final bool hasError = state is BatchJsonApplyError;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Tooltip(
              message:
                  'Overwrite captions for selected images using a '
                  'structured JSON template',
              child: AppButton(
                text: 'Batch Apply',
                isOutline: true,
                backgroundColor: accentPink,
                foregroundColor: accentPink,
                onTap: isInProgress
                    ? null
                    : () async {
                        if (_selectedOption == CaptionOptions.all &&
                            imageCount > 1) {
                          final bool? confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext ctx) {
                              return AlertDialog(
                                backgroundColor: panelRaised,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                title: const Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: amberWarn,
                                      size: 22,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Confirm Batch Apply',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  'This will overwrite captions for '
                                  '$imageCount images. '
                                  'This action cannot be undone.',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: amberWarn,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Continue'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmed != true || !context.mounted) return;
                        }
                        final BatchApplyTemplate? template =
                            await showDialog<BatchApplyTemplate>(
                              context: context,
                              builder: (BuildContext _) =>
                                  const BatchJsonApplyDialog(),
                            );
                        if (template != null && context.mounted) {
                          context.read<BatchJsonApplyCubit>().apply(template);
                        }
                      },
              ),
            ),
            if (isInProgress) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accentPink.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.processedImages}/${state.totalImages}',
                  style: const TextStyle(
                    color: accentPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StopButton(
                isCancelling: false,
                onTap: () => context.read<BatchJsonApplyCubit>().cancel(),
              ),
            ],
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: state.message,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: destructive.withAlpha(100),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: destructive,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Danger-style interrupt control. Squared stop glyph + danger glow,
/// lifts on hover, pulses while waiting for the in-flight job to settle.
class _StopButton extends StatefulWidget {
  const _StopButton({required this.onTap, required this.isCancelling});

  final VoidCallback onTap;
  final bool isCancelling;

  @override
  State<_StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<_StopButton>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant _StopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCancelling && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isCancelling && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = !widget.isCancelling;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _hover && enabled ? 1.035 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(
                    0xFFE5484D,
                  ).withAlpha(_hover && enabled ? 255 : 232),
                  const Color(
                    0xFFB32217,
                  ).withAlpha(_hover && enabled ? 245 : 214),
                ],
              ),
              border: Border.all(
                color: Colors.white.withAlpha(_hover && enabled ? 95 : 38),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(
                    0xFFE5484D,
                  ).withAlpha(_hover && enabled ? 130 : 72),
                  blurRadius: _hover ? 22 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.isCancelling)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(enabled ? 255 : 170),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                const SizedBox(width: 9),
                Text(
                  widget.isCancelling ? 'Stopping' : 'Stop',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    fontFamily: 'Orbitron',
                  ),
                ),
                if (widget.isCancelling) ...<Widget>[
                  const SizedBox(width: 8),
                  FadeTransition(
                    opacity: _pulse,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

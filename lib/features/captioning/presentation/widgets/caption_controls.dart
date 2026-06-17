import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/logic/llm_configs_cubit.dart';
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
  @override
  Widget build(BuildContext context) {
    return RadioGroup<CaptionOptions>(
      groupValue: _selectedOption,
      onChanged: (CaptionOptions? value) {
        setState(() {
          _selectedOption = value!;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
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
                    label: 'Missing captions',
                    option: CaptionOptions.missing,
                  ),
                  const SizedBox(width: 12),
                  _buildRadioButton(
                    label: 'All images',
                    option: CaptionOptions.all,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          _buildRunButton(),
        ],
      ),
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

  Widget _buildRunButton() => BlocBuilder<ImageListCubit, ImageListState>(
    builder: (BuildContext context, ImageListState imageListState) {
      return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
        builder: (BuildContext context, LlmConfigsState configState) {
          final bool ideogramMode = configState.llmConfigs.ideogramJsonEnabled;

          // Listen to the active cubit's state.
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
  }) {
    final Color accentColor = isIdeogram
        ? Colors.teal.withAlpha(220)
        : lightPink.withAlpha(220);
    final Color progressBg = isIdeogram
        ? Colors.teal.withAlpha(100)
        : Colors.green.withAlpha(100);
    final Color progressFg = isIdeogram ? Colors.teal : Colors.green;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Tooltip(
          message: isIdeogram
              ? 'Run Ideogram JSON structured pipeline'
              : 'Run Vision model with current settings',
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
                          );
                    } else {
                      context.read<CaptioningCubit>().runCaptioner(
                        llm: llm,
                        prompt: configState.llmConfigs.selectedPrompt!,
                        option: _selectedOption,
                      );
                    }
                  }
                : null,
          ),
        ),
        if (isIdeogram) const SizedBox(width: 8),
        if (isIdeogram) _buildBatchApplyButton(context),
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
                    color: Colors.red.withAlpha(100),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBatchApplyButton(BuildContext context) {
    return BlocBuilder<BatchJsonApplyCubit, BatchJsonApplyState>(
      builder: (BuildContext context, BatchJsonApplyState state) {
        final bool isInProgress = state is BatchJsonApplyInProgress;
        final bool hasError = state is BatchJsonApplyError;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Tooltip(
              message: 'Batch apply structured fields to all images',
              child: AppButton(
                text: 'Batch Apply',
                backgroundColor: const Color(0xFF7B68EE).withAlpha(220),
                onTap: isInProgress
                    ? null
                    : () async {
                        final BatchApplyTemplate? template =
                            await showDialog<BatchApplyTemplate>(
                              context: context,
                              builder: (BuildContext _) =>
                                  const BatchJsonApplyDialog(),
                            );
                        if (template != null && context.mounted) {
                          context
                              .read<BatchJsonApplyCubit>()
                              .apply(template);
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
                  color: const Color(0xFF7B68EE).withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.processedImages}/${state.totalImages}',
                  style: const TextStyle(
                    color: Color(0xFF7B68EE),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StopButton(
                isCancelling: false,
                onTap: () =>
                    context.read<BatchJsonApplyCubit>().cancel(),
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
                      color: Colors.red.withAlpha(100),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
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
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

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

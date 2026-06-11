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
import '../../data/models/caption_options.dart';
import '../../logic/captioning_cubit.dart';

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
            _buildRadioButton(label: 'All images', option: CaptionOptions.all),
            const SizedBox(width: 20),
            _buildRunButton(),
          ],
        ),
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
        if (isInProgress)
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
                const SizedBox(width: 8),
                Tooltip(
                  message: isCancelling
                      ? 'Waiting for last job...'
                      : 'Cancel captioning',
                  child: InkWell(
                    onTap: isCancelling
                        ? null
                        : () {
                            if (isIdeogram) {
                              context
                                  .read<StructuredCaptioningCubit>()
                                  .cancelStructuredCaptioning();
                            } else {
                              context
                                  .read<CaptioningCubit>()
                                  .cancelCaptioning();
                            }
                          },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isCancelling
                            ? Colors.white.withAlpha(10)
                            : Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: isCancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
}

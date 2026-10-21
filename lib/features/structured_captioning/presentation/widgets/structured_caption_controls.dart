import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../caption_session/caption_session.dart';
import '../../../captioning/captioning.dart';
import '../../../image_list/image_list.dart';
import '../../../llm_config/llm_config.dart';
import '../bloc/structured_captioning_cubit.dart';

class StructuredCaptionControls extends StatefulWidget {
  const StructuredCaptionControls({super.key});

  @override
  State<StructuredCaptionControls> createState() =>
      _StructuredCaptionControlsState();
}

class _StructuredCaptionControlsState extends State<StructuredCaptionControls> {
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
              "Structured: ",
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
              ? Colors.teal.withAlpha(80)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.teal.withAlpha(150)
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
                    return Colors.teal;
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
          // Select only the progress fields the row renders — the full state
          // also churns on per-image step/progress updates.
          return BlocSelector<
            StructuredCaptioningCubit,
            StructuredCaptioningState,
            (bool, String?, int, int, bool, String?)
          >(
            selector: (StructuredCaptioningState captioningState) => (
              captioningState.status == StructuredCaptioningStatus.inProgress,
              captioningState.stepLabel,
              captioningState.processedImages,
              captioningState.totalImages,
              captioningState.isCancelling,
              captioningState.error,
            ),
            builder:
                (
                  BuildContext context,
                  (bool, String?, int, int, bool, String?) progress,
                ) {
                  final (
                    bool isCaptioning,
                    String? stepLabel,
                    int processed,
                    int total,
                    bool isCancelling,
                    String? error,
                  ) = progress;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Tooltip(
                        message: 'Run structured VLM + SAM pipeline',
                        child: AppButton(
                          text: "▶  Structured",
                          isLoading: isCaptioning,
                          backgroundColor: Colors.teal.withAlpha(220),
                          onTap:
                              imageListState.images.isNotEmpty &&
                                  configState.llmConfigs.selectedConfigId !=
                                      null &&
                                  !isCaptioning
                              ? () {
                                  context
                                      .read<StructuredCaptioningCubit>()
                                      .runStructuredCaptioner(
                                        llm: configState.llmConfigs.configs
                                            .firstWhere(
                                              (LlmConfig c) =>
                                                  c.id ==
                                                  configState
                                                      .llmConfigs
                                                      .selectedConfigId,
                                            ),
                                        option: _selectedOption,
                                        overrides: configState
                                            .llmConfigs
                                            .structuredBatchOverrides,
                                        debugMode:
                                            configState.llmConfigs.debugMode,
                                        disableSam:
                                            configState.llmConfigs.disableSam,
                                        vlmEmitsXyxy:
                                            configState.llmConfigs.vlmEmitsXyxy,
                                        multiStage:
                                            configState.llmConfigs.multiStage,
                                      );
                                }
                              : null,
                        ),
                      ),
                      if (isCaptioning) ...<Widget>[
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withAlpha(100),
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
                                    style: const TextStyle(
                                      color: Colors.tealAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              Text(
                                "$processed/$total",
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: isCancelling
                                    ? 'Waiting for last job...'
                                    : 'Cancel structured captioning',
                                child: InkWell(
                                  onTap: isCancelling
                                      ? null
                                      : () {
                                          context
                                              .read<StructuredCaptioningCubit>()
                                              .cancelStructuredCaptioning();
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
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
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
                },
          );
        },
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/captioning/captioning_cubit.dart';
import '../../features/image_list/logic/image_list_cubit.dart';
import '../../logic/llm_config/llm_configs_cubit.dart';
import '../../models/caption_options.dart';
import '../../models/llm_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';

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
            const Text("Caption: "),
            _buildRadioButton(
              label: 'This image',
              option: CaptionOptions.current,
            ),
            const SizedBox(width: 8),
            _buildRadioButton(
              label: 'Missing captions',
              option: CaptionOptions.missing,
            ),
            const SizedBox(width: 8),
            _buildRadioButton(label: 'All', option: CaptionOptions.all),
            const SizedBox(width: 16),
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
    return InkWell(
      onTap: () => setState(() => _selectedOption = option),
      child: Row(
        children: <Widget>[
          Radio<CaptionOptions>(value: option),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildRunButton() => BlocBuilder<ImageListCubit, ImageListState>(
    builder: (BuildContext context, ImageListState imageListState) {
      return BlocBuilder<CaptioningCubit, CaptioningState>(
        builder: (BuildContext context, CaptioningState captioningState) {
          return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
            builder: (BuildContext context, LlmConfigsState configState) {
              final bool isCaptioning =
                  captioningState.status == CaptioningStatus.inProgress;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppButton(
                    text: "▶️  Run",
                    isLoading: isCaptioning,
                    backgroundColor: lightPink.withAlpha(200),
                    onTap:
                        imageListState.images.isNotEmpty &&
                            configState.llmConfigs.selectedConfigId != null &&
                            !isCaptioning
                        ? () {
                            context.read<CaptioningCubit>().runCaptioner(
                              llm: configState.llmConfigs.configs.firstWhere(
                                (LlmConfig c) =>
                                    c.id ==
                                    configState.llmConfigs.selectedConfigId,
                              ),
                              prompt: configState.llmConfigs.selectedPrompt!,
                              option: _selectedOption,
                            );
                          }
                        : null,
                  ),
                  if (isCaptioning)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        '${captioningState.processedImages}/${captioningState.totalImages}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (captioningState.error != null &&
                      captioningState.error!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Tooltip(
                        message: captioningState.error,
                        child: const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 16,
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

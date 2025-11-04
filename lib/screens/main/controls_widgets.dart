import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images_cubit.dart';
import '../../services/cache_service.dart';
import '../settings/llm_settings_screen.dart';
import '../widgets/app_button.dart';

class PickFolderButton extends StatelessWidget {
  const PickFolderButton();

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: "📂  Pick folder",
      onTap: () async {
        final String? selectedDirectory = await FilePicker.platform
            .getDirectoryPath(
              initialDirectory: context.read<ImagesCubit>().state.folderPath,
            );
        if (selectedDirectory != null) {
          context.read<ImagesCubit>().onFolderPicked(selectedDirectory);
          CacheService.saveFolderPath(selectedDirectory);
        }
      },
    );
  }
}

class ApiSettingsButton extends StatelessWidget {
  const ApiSettingsButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider<ImagesCubit>.value(
              value: context.read<ImagesCubit>(),
              child: const LlmSettingsScreen(),
            ),
          ),
        );
      },
      child: const Text("⚙️"),
    );
  }
}

class RenameAllFilesButton extends StatelessWidget {
  const RenameAllFilesButton();

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: "📘  Rename all files",
      onTap: () {
        context.read<ImagesCubit>().renameAllFiles();
      },
    );
  }
}

class CaptionControls extends StatefulWidget {
  const CaptionControls({super.key});

  @override
  State<CaptionControls> createState() => _CaptionControlsState();
}

class _CaptionControlsState extends State<CaptionControls> {
  String _selectedOption = 'caption_this';

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: _selectedOption,
      onChanged: (String? value) {
        setState(() {
          _selectedOption = value!;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildRadioButton(label: 'Caption this image', value: 'caption_this'),
          const SizedBox(width: 8),
          _buildRadioButton(label: 'Caption all images', value: 'caption_all'),
          const SizedBox(width: 16),
          _buildRunButton(),
        ],
      ),
    );
  }

  Widget _buildRadioButton({required String label, required String value}) {
    return Row(
      children: <Widget>[
        Radio<String>(value: value),
        Text(label),
      ],
    );
  }

  Widget _buildRunButton() => BlocBuilder<ImagesCubit, ImagesState>(
    builder: (BuildContext context, ImagesState state) {
      return AppButton(
        text: "▶️  Run",
        onTap:
            state.images.isNotEmpty && state.llmConfigs.selectedConfigId != null
            ? () {
                if (_selectedOption == 'caption_this') {
                  context.read<ImagesCubit>().captionCurrentImage();
                } else if (_selectedOption == 'caption_all') {
                  context.read<ImagesCubit>().captionAllEmpty();
                }
              }
            : null,
      );
    },
  );
}

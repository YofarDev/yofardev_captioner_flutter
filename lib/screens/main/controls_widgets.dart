import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images/images_cubit.dart';
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

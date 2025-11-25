import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../logic/image_operations/image_operations_cubit.dart';
import '../../logic/images_list/image_list_cubit.dart';
import '../main/convert_images_dialog.dart';
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
              initialDirectory: context.read<ImageListCubit>().state.folderPath,
            );
        if (selectedDirectory != null) {
          context.read<ImageListCubit>().onFolderPicked(selectedDirectory);
        }
      },
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton();
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LlmSettingsScreen()),
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
        context.read<ImageOperationsCubit>().renameAllFiles();
      },
    );
  }
}

class ConvertAllImagesButton extends StatelessWidget {
  const ConvertAllImagesButton({super.key});
  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: '📸  Convert all images',
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => MultiBlocProvider(
            providers: <SingleChildWidget>[
              BlocProvider<ImageListCubit>.value(
                value: context.read<ImageListCubit>(),
              ),
              BlocProvider<ImageOperationsCubit>.value(
                value: context.read<ImageOperationsCubit>(),
              ),
            ],
            child: const ConvertImagesDialog(),
          ),
        );
      },
    );
  }
}

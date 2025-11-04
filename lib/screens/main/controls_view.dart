import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images_cubit.dart';
import '../../services/cache_service.dart';
import '../widgets/app_button.dart';
import 'search_and_replace_widget.dart';

class ControlsView extends StatelessWidget {
  const ControlsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 5,
      child: Row(
        children: <Widget>[
          const _PickFolderButton(),
          const _ApiSettingsButton(),
          AppButton(
            text: "Rename all files",
            onTap: () {
              context.read<ImagesCubit>().renameAllFiles();
            },
          ),
          const SizedBox(width: 20),
          const SearchAndReplaceWidget(),
        ],
      ),
    );
  }
}

class _PickFolderButton extends StatelessWidget {
  const _PickFolderButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final String? selectedDirectory = await FilePicker.platform
            .getDirectoryPath(
              initialDirectory: context.read<ImagesCubit>().state.folderPath,
            );
        if (selectedDirectory != null) {
          context.read<ImagesCubit>().onFolderPicked(selectedDirectory);
          CacheService.saveFolderPath(selectedDirectory);
        }
      },
      child: const Text("📂"),
    );
  }
}

class _ApiSettingsButton extends StatelessWidget {
  const _ApiSettingsButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
      },
      child: const Text("⚙️"),
    );
  }
}

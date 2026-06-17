import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../llm_config/presentation/pages/llm_settings_screen.dart';
import '../../../tab_manager/data/models/app_tab.dart';
import '../../../tab_manager/logic/tab_manager_cubit.dart';
import '../../logic/image_operations_cubit.dart';
import '../pages/convert_images_dialog.dart';

class PickFolderButton extends StatelessWidget {
  final bool outlined;
  const PickFolderButton({super.key, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Select a folder containing images to caption',
      child: AppButton(
        text: "Pick folder",
        iconAssetPath: 'assets/icons/folder.png',
        isOutline: outlined,
        onTap: () async {
          final String? selectedDirectory = await FilePicker.getDirectoryPath(
            initialDirectory: context.read<ImageListCubit>().state.folderPath,
          );
          if (selectedDirectory != null) {
            final TabManagerCubit tabManager = context.read<TabManagerCubit>();
            final AppTab activeTab = tabManager.state.activeTab;
            tabManager.updateTabFolderPath(activeTab.id, selectedDirectory);
            context.read<ImageListCubit>().onFolderPicked(selectedDirectory);
          }
        },
      ),
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open Vision model settings',
      child: TextButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LlmSettingsScreen()),
          );
        },
        child: const Icon(Icons.tune, color: pinkDim, size: 20),
      ),
    );
  }
}

class RenameAllFilesButton extends StatelessWidget {
  final bool outlined;
  const RenameAllFilesButton({super.key, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Rename all image files to sequential numbers (01, 02, 03...)',
      child: AppButton(
        text: "Rename all files",
        iconAssetPath: 'assets/icons/rename.png',
        isOutline: outlined,
        onTap: () async {
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
                      'Rename all files',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                content: const Text(
                  'This will rename all image files to sequential numbers '
                  '(01, 02, 03...). This action cannot be undone.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: destructive,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Rename'),
                  ),
                ],
              );
            },
          );
          if (confirmed != true) return;
          if (!context.mounted) return;
          context.read<ImageOperationsCubit>().renameAllFiles();
        },
      ),
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

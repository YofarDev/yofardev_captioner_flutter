import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../image_list/image_list.dart';
import '../bloc/image_operations_cubit.dart';
import '../pages/convert_images_dialog.dart';

class PickFolderButton extends StatelessWidget {
  const PickFolderButton({
    super.key,
    this.outlined = false,
    required this.onFolderPicked,
  });

  final bool outlined;

  /// Invoked with the picked directory. The composition root decides what a
  /// "folder picked" means (update the active tab, reload the image list).
  final void Function(String folderPath) onFolderPicked;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Select a folder containing images to caption',
      child: AppButton(
        text: "Pick folder",
        iconAssetPath: 'assets/icons/folder.png',
        isOutline: outlined,
        onTap: () async {
          final String? currentFolder = context
              .read<ImageListCubit>()
              .state
              .folderPath;
          final String? selectedDirectory = await FilePicker.getDirectoryPath(
            initialDirectory: currentFolder,
          );
          if (selectedDirectory != null) {
            onFolderPicked(selectedDirectory);
          }
        },
      ),
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, required this.onPressed});

  /// Navigation is owned by the composition root — this feature does not
  /// import the settings screen.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open Vision model settings',
      child: TextButton(
        onPressed: onPressed,
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
  const ConvertAllImagesButton();

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: 'Convert all images',
      iconData: Icons.photo_size_select_large,
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

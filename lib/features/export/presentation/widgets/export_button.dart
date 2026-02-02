import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_operations/logic/image_operations_cubit.dart';

class ExportButton extends StatelessWidget {
  const ExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Export images and captions as zip file',
      child: AppButton(
        onTap: () => _showExportDialog(context),
        text: 'Export as Archive',
        iconAssetPath: 'assets/icons/archive.png',
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => const _ExportCategoryDialog(),
    );
  }
}

class _ExportCategoryDialog extends StatefulWidget {
  const _ExportCategoryDialog();

  @override
  State<_ExportCategoryDialog> createState() => _ExportCategoryDialogState();
}

class _ExportCategoryDialogState extends State<_ExportCategoryDialog> {
  String? selectedCategory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize with active category when dependencies change
    final ImageListState state = context.read<ImageListCubit>().state;
    if (selectedCategory == null && state.activeCategory != null) {
      selectedCategory = state.activeCategory!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        if (state.categories.isEmpty) {
          return AlertDialog(
            title: const Text('Export'),
            content: const Text('No categories available.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }

        selectedCategory ??= state.activeCategory ?? state.categories.first;
        final int imagesWithCaption = state.images
            .where((AppImage img) =>
                (img.captions[selectedCategory!]?.text ?? '').isNotEmpty)
            .length;

        return AlertDialog(
          title: const Text('Export as Archive'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Select caption category to export:'),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                items: state.categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Will export ${state.images.length} images',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '$imagesWithCaption images have captions in "$selectedCategory"',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (imagesWithCaption < state.images.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠️ ${state.images.length - imagesWithCaption} images have no caption in this category',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                context.read<ImageOperationsCubit>().exportAsArchive(
                      state.folderPath!,
                      state.images,
                      selectedCategory!,
                    );
                Navigator.pop(context);
              },
              child: const Text('Export'),
            ),
          ],
        );
      },
    );
  }
}

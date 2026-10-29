import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../caption_session/caption_session.dart';
import '../../../image_list/image_list.dart';
import '../../../image_operations/image_operations.dart';
import '../bloc/moss_training_export_cubit.dart';
import 'moss_training_export_dialog.dart';

class ExportButton extends StatelessWidget {
  final bool outlined;
  const ExportButton({super.key, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Export images and captions as zip file',
      child: AppButton(
        onTap: () => _showExportDialog(context),
        text: 'Export as Archive',
        iconAssetPath: 'assets/icons/archive.png',
        isOutline: outlined,
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    // Capture cubits HERE — at ExportButton's position inside the tab
    // provider subtree (which sits BELOW the app Navigator) — and forward
    // them across the dialog boundary. showDialog routes are inserted above
    // this widget, so the inner dialog context cannot see the tab providers;
    // without the forward, MossTrainingExportCubit raises
    // ProviderNotFoundException (Codex rev-2 finding 1).
    final ImageListCubit imageListCubit = context.read<ImageListCubit>();
    final ImageOperationsCubit imageOperationsCubit = context
        .read<ImageOperationsCubit>();
    final MossTrainingExportCubit mossTrainingExportCubit = context
        .read<MossTrainingExportCubit>();
    showDialog(
      context: context,
      builder: (BuildContext context) => MultiBlocProvider(
        providers: <SingleChildWidget>[
          BlocProvider<ImageListCubit>.value(value: imageListCubit),
          BlocProvider<ImageOperationsCubit>.value(value: imageOperationsCubit),
          BlocProvider<MossTrainingExportCubit>.value(
            value: mossTrainingExportCubit,
          ),
        ],
        child: const _ExportCategoryDialog(),
      ),
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
    final ImageListState state = context.read<ImageListCubit>().state;
    if (selectedCategory == null && state.activeCategory != null) {
      selectedCategory = state.activeCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        if (state.categories.isEmpty) {
          return AlertDialog(
            backgroundColor: darkGrey,
            title: const Text('Export', style: TextStyle(color: Colors.white)),
            content: const Text(
              'No categories available.',
              style: TextStyle(color: Colors.white70),
            ),
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
            .where(
              (AppImage img) =>
                  (img.captions[selectedCategory!]?.text ?? '').isNotEmpty,
            )
            .length;

        return AlertDialog(
          backgroundColor: darkGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Export as Archive',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Select caption category to export:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      dropdownColor: darkGrey,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                      ),
                      items: state.categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            category,
                            style: const TextStyle(color: Colors.white),
                          ),
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
                  ),
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: Icons.image_outlined,
                  label: 'Total images:',
                  value: '${state.images.length}',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.description_outlined,
                  label: 'With captions:',
                  value: '$imagesWithCaption',
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _openTrainingExport(context, state),
                  icon: const Icon(Icons.model_training, size: 18),
                  label: const Text(
                    'MOSS training dataset…',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                if (imagesWithCaption < state.images.length) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(30)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${state.images.length - imagesWithCaption} images have no caption in this category',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withAlpha(150)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightPink,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _confirmExport(context, state),
                child: const Text(
                  'Export',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openTrainingExport(BuildContext context, ImageListState state) {
    final String category = selectedCategory!;
    // Codex rev-3 finding 1: imageListCubit comes from the forwarded tab
    // providers (this context sits inside the first dialog) and provides
    // LIVE session state for staleness checks. The MossTrainingExportCubit
    // was forwarded across the FIRST dialog boundary by [_showExportDialog];
    // this SECOND showDialog route sits above the navigator again, so it
    // needs its own .value wrap.
    final ImageListCubit imageListCubit = context.read<ImageListCubit>();
    final MossTrainingExportCubit mossTrainingExportCubit = context
        .read<MossTrainingExportCubit>();
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) =>
          BlocProvider<MossTrainingExportCubit>.value(
            value: mossTrainingExportCubit,
            child: MossTrainingExportDialog(
              images: state.images,
              category: category,
              imageListCubit: imageListCubit,
              key: const ValueKey<String>('moss-training-export'),
            ),
          ),
    );
  }

  void _confirmExport(BuildContext context, ImageListState state) {
    final int totalImages = state.images.length;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: darkGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Confirm Export',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Create archive of $totalImages images with captions in '
            'category "$selectedCategory"?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: lightPink,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                context.read<ImageOperationsCubit>().exportAsArchive(
                  state.folderPath!,
                  state.images,
                  selectedCategory!,
                );
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Export',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

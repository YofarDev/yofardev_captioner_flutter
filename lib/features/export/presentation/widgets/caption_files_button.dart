import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../structured_captioning/data/models/ideogram_caption.dart';

class CaptionFilesButton extends StatelessWidget {
  final bool outlined;
  const CaptionFilesButton({super.key, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Left-click: create caption files | Right-click: remove all',
      child: GestureDetector(
        onSecondaryTap: () => _onRemove(context),
        child: AppButton(
          text: 'Create caption files',
          iconAssetPath: 'assets/icons/words.png',
          isOutline: outlined,
          onTap: () => _onWrite(context),
        ),
      ),
    );
  }

  /// Returns the format for [category]: explicit if stored, else auto-detected
  /// from the first non-empty caption (Ideogram JSON → 'json', else 'txt').
  static String _effectiveFormat(ImageListState state, String category) {
    final String? stored = state.categoryFormats[category];
    if (stored != null) return stored;
    for (final AppImage image in state.images) {
      final String text = image.captions[category]?.text ?? '';
      if (IdeogramCaption.isIdeogramJson(text)) return 'json';
      if (text.isNotEmpty) return 'txt';
    }
    return 'txt';
  }

  void _onWrite(BuildContext context) {
    final ImageListCubit cubit = context.read<ImageListCubit>();
    final ImageListState state = cubit.state;
    if (state.folderPath == null) return;

    final String category = state.activeCategory ?? 'default';
    final String format = _effectiveFormat(state, category);

    final int withCaption = state.images
        .where(
          (AppImage img) => (img.captions[category]?.text ?? '').isNotEmpty,
        )
        .length;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: darkGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Create Caption Files',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Create ${format.toUpperCase()} caption files for '
            '"$category" ($withCaption with captions)?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withAlpha(150)),
              ),
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
                cubit.writeCaptionFiles();
                Navigator.pop(ctx);
              },
              child: const Text(
                'Create',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onRemove(BuildContext context) {
    final ImageListCubit cubit = context.read<ImageListCubit>();
    final ImageListState state = cubit.state;
    if (state.folderPath == null) return;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: darkGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: destructive, size: 22),
              SizedBox(width: 10),
              Text(
                'Remove Caption Files',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Delete all .txt and .json caption files in this folder?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withAlpha(150)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: destructive,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                cubit.removeCaptionFiles();
                Navigator.pop(ctx);
              },
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

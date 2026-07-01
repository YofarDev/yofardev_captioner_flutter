import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../image_list/logic/image_list_cubit.dart';

/// Edits the per-image guidance text, opened from the Run row.
///
/// The text is keyed by the displayed image's path and stored live in
/// [ImageListCubit] (on every keystroke) so it persists when the dialog closes.
/// The enable toggle lives on the Run row; this dialog is the text editor.
class GuidanceDialog extends StatefulWidget {
  const GuidanceDialog({super.key});

  @override
  State<GuidanceDialog> createState() => _GuidanceDialogState();
}

class _GuidanceDialogState extends State<GuidanceDialog> {
  late final ImageListCubit _cubit;
  late final TextEditingController _controller;
  late final String? _path;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ImageListCubit>();
    _path = _cubit.currentDisplayedImage?.image.path;
    _controller = TextEditingController(
      text: _path == null ? '' : (_cubit.state.imageGuidance[_path] ?? ''),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    // Persist guidance to db.json so it survives across sessions.
    _cubit.saveChanges();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: panelDark,
      title: const Text('Per-image guidance'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Broadcast to every image on the next Run / JSON Run.',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: _path != null,
              minLines: 2,
              maxLines: 5,
              style: const TextStyle(color: textPrimary, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText:
                    _path == null ? 'No image selected' : "e.g. Name the character 'Mira'",
                hintStyle: const TextStyle(color: textMuted, fontSize: 12),
                filled: true,
                fillColor: shellBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: accentPink),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: hairline),
                ),
              ),
              onChanged: (String value) {
                if (_path != null) {
                  _cubit.setGuidance(_path, value);
                }
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

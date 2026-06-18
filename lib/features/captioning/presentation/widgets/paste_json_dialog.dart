import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../data/utils/ideogram_json.dart';

/// Dialog that lets the user paste a raw Ideogram JSON blob and apply it
/// (strictly validated + normalized) as the caption for the currently selected
/// image in the active category.
class PasteJsonDialog extends StatefulWidget {
  const PasteJsonDialog({super.key});

  @override
  State<PasteJsonDialog> createState() => _PasteJsonDialogState();
}

class _PasteJsonDialogState extends State<PasteJsonDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  IdeogramJsonResult _result =
      const IdeogramJsonResult.failure('Input is empty.');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _validate(String value) {
    setState(() => _result = parseIdeogramCaptionJson(value));
  }

  Future<void> _apply() async {
    if (!_result.isSuccess) return;
    final String normalized = _result.normalized!;
    await context.read<ImageListCubit>().updateCaption(caption: normalized);
    if (!mounted) return;
    NotificationOverlay.show(context, message: 'Caption applied');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: darkGrey,
      title: const Row(
        children: <Widget>[
          Icon(Icons.data_object, color: lightPink, size: 22),
          SizedBox(width: 10),
          Text(
            'Paste JSON caption',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Paste a raw Ideogram caption JSON. It will be validated and '
              'applied to the current image in the active category.',
              style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              focusNode: _focus,
              minLines: 8,
              maxLines: 12,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: '{"high_level_description": ..., '
                    '"compositional_deconstruction": {...}}',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: lightGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _validate,
            ),
            const SizedBox(height: 8),
            if (!_result.isSuccess && _result.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.error_outline,
                        size: 14, color: destructive.withAlpha(200)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _result.error!,
                        style: TextStyle(
                          fontSize: 11,
                          color: destructive.withAlpha(220),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        AppButton(
          text: 'Apply',
          backgroundColor: lightPink.withAlpha(220),
          onTap: _result.isSuccess ? _apply : null,
        ),
      ],
    );
  }
}

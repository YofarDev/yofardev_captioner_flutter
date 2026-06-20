import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Opens a modal dialog collecting optional instructions for single-element
/// recaptioning. Returns the trimmed instructions (empty string if the user
/// confirms with the field blank), or null if they cancel.
Future<String?> showRecaptionElementDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => const _RecaptionElementDialog(),
  );
}

class _RecaptionElementDialog extends StatefulWidget {
  const _RecaptionElementDialog();

  @override
  State<_RecaptionElementDialog> createState() =>
      _RecaptionElementDialogState();
}

class _RecaptionElementDialogState extends State<_RecaptionElementDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: lightGrey,
      title: const Text(
        'Recaption element',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Additional instructions (optional)',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            maxLines: 3,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: "e.g. 'focus on the branding', 'describe the material'",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: darkGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Recaption'),
        ),
      ],
    );
  }
}

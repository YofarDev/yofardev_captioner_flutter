import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../logic/llm_configs_cubit.dart';

/// Add / edit a prompt. Behaviour preserved from the original inline dialog.
class PromptDialog extends StatefulWidget {
  final String? oldPrompt;
  final int? index;
  final VoidCallback? onAdded;

  const PromptDialog({super.key, this.oldPrompt, this.index, this.onAdded});

  static Future<void> show(
    BuildContext context, {
    String? oldPrompt,
    int? index,
    VoidCallback? onAdded,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          PromptDialog(oldPrompt: oldPrompt, index: index, onAdded: onAdded),
    );
  }

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.oldPrompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.oldPrompt != null;

    return AlertDialog(
      backgroundColor: panelRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: hairline),
      ),
      title: Row(
        children: <Widget>[
          Icon(
            isEditing ? Icons.edit_note : Icons.playlist_add,
            color: lightPink,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            isEditing ? 'Edit Prompt' : 'Add Prompt',
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 4),
            TextField(
              controller: _promptController,
              autofocus: true,
              maxLines: 6,
              minLines: 3,
              style: const TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Prompt',
                hintText: 'You are a helpful assistant...',
                alignLabelWithHint: true,
                labelStyle: const TextStyle(color: textSecondary),
                floatingLabelStyle: const TextStyle(color: lightPink),
                filled: true,
                fillColor: panelDark,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: BorderSide(
                    color: lightPink.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: lightPink,
            foregroundColor: darkGrey,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final String newPrompt = _promptController.text;
    if (newPrompt.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.oldPrompt != null) {
      context.read<LlmConfigsCubit>().updatePromptByIndex(
        newPrompt,
        widget.index!,
      );
    } else {
      context.read<LlmConfigsCubit>().addPrompt(newPrompt);
      widget.onAdded?.call();
    }
    Navigator.of(context).pop();
  }
}

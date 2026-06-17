import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/logic/llm_configs_cubit.dart';
import '../../logic/captioning_cubit.dart';

/// Dialog that asks the active LLM to rewrite the current caption (text-only,
/// no image is sent) according to free-form user instructions. The LLM returns
/// the full rewritten caption, which replaces the current one on success.
class RewriteCaptionDialog extends StatefulWidget {
  const RewriteCaptionDialog({required this.currentCaption, super.key});

  final String currentCaption;

  @override
  State<RewriteCaptionDialog> createState() => _RewriteCaptionDialogState();
}

class _RewriteCaptionDialogState extends State<RewriteCaptionDialog> {
  final TextEditingController _instructionsController = TextEditingController();
  final FocusNode _instructionsFocus = FocusNode();
  bool _isRewriting = false;

  @override
  void initState() {
    super.initState();
    // Autofocus the instructions field once the frame is built.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _instructionsFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _instructionsFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String instructions = _instructionsController.text.trim();
    if (instructions.isEmpty) {
      NotificationOverlay.show(
        context,
        message: 'Enter rewrite instructions',
        backgroundColor: Colors.red.shade800,
      );
      return;
    }

    final LlmConfigsState configState = context.read<LlmConfigsCubit>().state;
    final String? selectedId = configState.llmConfigs.selectedConfigId;
    if (selectedId == null) {
      NotificationOverlay.show(
        context,
        message: 'Select an LLM configuration first',
        backgroundColor: Colors.red.shade800,
      );
      return;
    }
    final LlmConfig llm = configState.llmConfigs.configs.firstWhere(
      (LlmConfig c) => c.id == selectedId,
    );

    setState(() => _isRewriting = true);
    try {
      await context.read<CaptioningCubit>().rewriteCaption(
        llm: llm,
        instructions: instructions,
      );
      if (!mounted) {
        return;
      }
      NotificationOverlay.show(context, message: 'Caption rewritten');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isRewriting = false);
      NotificationOverlay.show(
        context,
        message: 'Rewrite failed: $e',
        backgroundColor: Colors.red.shade800,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: darkGrey,
      title: const Row(
        children: <Widget>[
          Icon(Icons.auto_fix_high, color: lightPink, size: 22),
          SizedBox(width: 10),
          Text(
            'Rewrite caption',
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
              'Current caption',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.currentCaption.trim().isEmpty
                      ? '(empty)'
                      : widget.currentCaption,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Instructions',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _instructionsController,
              focusNode: _instructionsFocus,
              enabled: !_isRewriting,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. make the person a young woman',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: lightGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isRewriting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        AppButton(
          text: 'Rewrite',
          isLoading: _isRewriting,
          backgroundColor: lightPink.withAlpha(220),
          onTap: _isRewriting ? null : _submit,
        ),
      ],
    );
  }
}

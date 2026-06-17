import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../structured_captioning/presentation/widgets/color_palette_editor.dart';
import '../../data/models/batch_apply_template.dart';

class BatchJsonApplyDialog extends StatefulWidget {
  const BatchJsonApplyDialog({super.key});

  @override
  State<BatchJsonApplyDialog> createState() => _BatchJsonApplyDialogState();
}

class _BatchJsonApplyDialogState extends State<BatchJsonApplyDialog> {
  final TextEditingController _highLevelDescCtrl = TextEditingController();
  final TextEditingController _aestheticsCtrl = TextEditingController();
  final TextEditingController _lightingCtrl = TextEditingController();
  final TextEditingController _mediumCtrl = TextEditingController(text: 'photograph');
  final TextEditingController _photoCtrl = TextEditingController();
  final TextEditingController _artStyleCtrl = TextEditingController();
  final TextEditingController _backgroundCtrl = TextEditingController();
  List<String> _colorPalette = <String>[];

  @override
  void dispose() {
    _highLevelDescCtrl.dispose();
    _aestheticsCtrl.dispose();
    _lightingCtrl.dispose();
    _mediumCtrl.dispose();
    _photoCtrl.dispose();
    _artStyleCtrl.dispose();
    _backgroundCtrl.dispose();
    super.dispose();
  }

  BatchApplyTemplate _buildTemplate() {
    return BatchApplyTemplate(
      highLevelDescription:
          _highLevelDescCtrl.text.isNotEmpty ? _highLevelDescCtrl.text : null,
      aesthetics:
          _aestheticsCtrl.text.isNotEmpty ? _aestheticsCtrl.text : null,
      lighting: _lightingCtrl.text.isNotEmpty ? _lightingCtrl.text : null,
      medium: _mediumCtrl.text.isNotEmpty ? _mediumCtrl.text : null,
      photo: _mediumCtrl.text == 'photograph' && _photoCtrl.text.isNotEmpty
          ? _photoCtrl.text
          : null,
      artStyle: _mediumCtrl.text != 'photograph' && _artStyleCtrl.text.isNotEmpty
          ? _artStyleCtrl.text
          : null,
      colorPalette: _colorPalette.isNotEmpty ? _colorPalette : null,
      background:
          _backgroundCtrl.text.isNotEmpty ? _backgroundCtrl.text : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPhoto = _mediumCtrl.text == 'photograph';

    return Dialog(
      backgroundColor: lightGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Batch Apply Structured Fields',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fill in fields to apply. Empty fields are skipped.',
                style: TextStyle(fontSize: 13, color: Colors.white60),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _field('High-level description', _highLevelDescCtrl,
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _field('Aesthetics', _aestheticsCtrl),
                      const SizedBox(height: 12),
                      _field('Lighting', _lightingCtrl),
                      const SizedBox(height: 12),
                      _field('Medium', _mediumCtrl,
                          onChanged: (_) => setState(() {})),
                      const SizedBox(height: 12),
                      if (isPhoto)
                        _field('Photo details', _photoCtrl)
                      else
                        _field('Art style', _artStyleCtrl),
                      const SizedBox(height: 12),
                      const Text(
                        'Color Palette',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ColorPaletteEditor(
                        colors: _colorPalette,
                        onChanged: (List<String> v) =>
                            setState(() => _colorPalette = v),
                      ),
                      const SizedBox(height: 12),
                      _field('Background', _backgroundCtrl, maxLines: 3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    text: 'Apply',
                    backgroundColor: Colors.teal.withAlpha(220),
                    onTap: () {
                      final BatchApplyTemplate template = _buildTemplate();
                      Navigator.of(context).pop(template);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {int maxLines = 1, ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withAlpha(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withAlpha(30)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

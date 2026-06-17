import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
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
  final TextEditingController _mediumCtrl = TextEditingController();
  final TextEditingController _photoCtrl = TextEditingController();
  final TextEditingController _artStyleCtrl = TextEditingController();
  final TextEditingController _backgroundCtrl = TextEditingController();

  bool _isPhoto = true;

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
    final String medium = _isPhoto ? 'photograph' : _mediumCtrl.text;
    return BatchApplyTemplate(
      highLevelDescription: _highLevelDescCtrl.text.isNotEmpty
          ? _highLevelDescCtrl.text
          : null,
      aesthetics: _aestheticsCtrl.text.isNotEmpty ? _aestheticsCtrl.text : null,
      lighting: _lightingCtrl.text.isNotEmpty ? _lightingCtrl.text : null,
      medium: medium.isNotEmpty ? medium : null,
      photo: _isPhoto && _photoCtrl.text.isNotEmpty ? _photoCtrl.text : null,
      artStyle: !_isPhoto && _artStyleCtrl.text.isNotEmpty
          ? _artStyleCtrl.text
          : null,
      background: _backgroundCtrl.text.isNotEmpty ? _backgroundCtrl.text : null,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      _field(
                        'High-level description',
                        _highLevelDescCtrl,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Type',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ToggleButtons(
                        isSelected: <bool>[_isPhoto, !_isPhoto],
                        onPressed: (int index) {
                          setState(() {
                            _isPhoto = index == 0;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: Colors.teal.withAlpha(180),
                        color: Colors.white60,
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          minWidth: 120,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        children: const <Widget>[
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Photo'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Art Style'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isPhoto)
                        _field('Camera', _photoCtrl)
                      else ...<Widget>[
                        _field('Medium', _mediumCtrl),
                        const SizedBox(height: 12),
                        _field('Art style', _artStyleCtrl),
                      ],
                      const SizedBox(height: 12),
                      _field('Aesthetics', _aestheticsCtrl),
                      const SizedBox(height: 12),
                      _field('Lighting', _lightingCtrl),
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
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white60),
                    ),
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

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
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
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

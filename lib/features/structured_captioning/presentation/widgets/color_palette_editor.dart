import 'package:flutter/material.dart';

import 'color_picker_dialog.dart';

/// Editable row of color swatches with add/remove/pick.
class ColorPaletteEditor extends StatelessWidget {
  const ColorPaletteEditor({
    required this.colors,
    required this.onChanged,
    super.key,
  });

  final List<String> colors;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        ...List<Widget>.generate(colors.length, (int index) {
          return _ColorSwatch(
            hex: colors[index],
            onTap: () => _editColor(context, index),
            onRemove: () => _removeColor(index),
          );
        }),
        _AddSwatchButton(onTap: () => _addColor(context)),
      ],
    );
  }

  Future<void> _editColor(BuildContext context, int index) async {
    final String? newColor = await showColorPickerDialog(
      context,
      initialColor: colors[index],
    );
    if (newColor != null && newColor != colors[index]) {
      final List<String> updated = List<String>.from(colors);
      updated[index] = newColor;
      onChanged(updated);
    }
  }

  Future<void> _addColor(BuildContext context) async {
    final String? newColor = await showColorPickerDialog(context);
    if (newColor != null) {
      final List<String> updated = List<String>.from(colors)..add(newColor);
      onChanged(updated);
    }
  }

  void _removeColor(int index) {
    final List<String> updated = List<String>.from(colors)..removeAt(index);
    onChanged(updated);
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.onTap,
    required this.onRemove,
  });

  final String hex;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  Color get _color {
    final String clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return Color(int.parse(clean, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTap: onRemove,
      child: Tooltip(
        message: '$hex\n(right-click to remove)',
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
        ),
      ),
    );
  }
}

class _AddSwatchButton extends StatelessWidget {
  const _AddSwatchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: 'Add color',
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38),
          ),
          child: const Icon(Icons.add, size: 16, color: Colors.white54),
        ),
      ),
    );
  }
}

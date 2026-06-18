import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/ideogram_caption.dart';
import '../../logic/structured_editor_cubit.dart';
import 'color_palette_editor.dart';

/// Editable section for IdeogramStyleDescription fields.
class StyleEditorSection extends StatelessWidget {
  const StyleEditorSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final StructuredEditorCubit cubit = context
            .read<StructuredEditorCubit>();
        final IdeogramStyleDescription style = state.caption.styleDescription;
        final bool isPhoto = style.medium == 'photograph';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _SectionLabel('Style'),
            const SizedBox(height: 8),
            _FieldRow(
              label: 'Medium',
              child: _CompactField(
                value: style.medium,
                onChanged: cubit.updateMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (isPhoto)
              _FieldRow(
                label: 'Camera',
                child: _CompactField(
                  value: style.photo ?? '',
                  onChanged: (String v) =>
                      cubit.updatePhoto(v.isEmpty ? null : v),
                ),
              )
            else
              _FieldRow(
                label: 'Art Style',
                child: _CompactField(
                  value: style.artStyle ?? '',
                  onChanged: (String v) =>
                      cubit.updateArtStyle(v.isEmpty ? null : v),
                ),
              ),
            const SizedBox(height: 8),
            _FieldRow(
              label: 'Aesthetics',
              child: _CompactField(
                value: style.aesthetics,
                onChanged: cubit.updateAesthetics,
              ),
            ),
            const SizedBox(height: 8),
            _FieldRow(
              label: 'Lighting',
              child: _CompactField(
                value: style.lighting,
                onChanged: cubit.updateLighting,
              ),
            ),
            const SizedBox(height: 8),
            const _SectionLabel('Color Palette'),
            const SizedBox(height: 6),
            ColorPaletteEditor(
              colors: style.colorPalette,
              onChanged: cubit.updateStyleColorPalette,
              imageFile: state.imageFile,
            ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _CompactField extends StatefulWidget {
  const _CompactField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_CompactField> createState() => _CompactFieldState();
}

class _CompactFieldState extends State<_CompactField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CompactField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      onChanged: widget.onChanged,
    );
  }
}

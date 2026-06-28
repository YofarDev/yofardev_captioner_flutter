import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/color_extraction_service.dart';
import '../../logic/structured_editor_cubit.dart';
import 'color_palette_editor.dart';
import 'editor_primitives.dart';

/// Editable fields for [IdeogramStyleDescription].
///
/// Renders only the fields — the owning panel provides the "Style" header so
/// every section shares the same rhythm.
class StyleEditorSection extends StatelessWidget {
  const StyleEditorSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final StructuredEditorCubit cubit = context
            .read<StructuredEditorCubit>();
        final bool isPhoto = state.caption.styleDescription.medium ==
            'photograph';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LabeledFieldRow(
              label: 'Medium',
              child: EditorTextField(
                value: state.caption.styleDescription.medium,
                dense: true,
                onChanged: cubit.updateMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (isPhoto)
              LabeledFieldRow(
                label: 'Camera',
                child: EditorTextField(
                  value: state.caption.styleDescription.photo ?? '',
                  dense: true,
                  onChanged: (String v) =>
                      cubit.updatePhoto(v.isEmpty ? null : v),
                ),
              )
            else
              LabeledFieldRow(
                label: 'Art Style',
                child: EditorTextField(
                  value: state.caption.styleDescription.artStyle ?? '',
                  dense: true,
                  onChanged: (String v) =>
                      cubit.updateArtStyle(v.isEmpty ? null : v),
                ),
              ),
            const SizedBox(height: 8),
            LabeledFieldRow(
              label: 'Aesthetics',
              child: EditorTextField(
                value: state.caption.styleDescription.aesthetics,
                dense: true,
                onChanged: cubit.updateAesthetics,
              ),
            ),
            const SizedBox(height: 8),
            LabeledFieldRow(
              label: 'Lighting',
              child: EditorTextField(
                value: state.caption.styleDescription.lighting,
                dense: true,
                onChanged: cubit.updateLighting,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const SectionLabel('Color Palette'),
                const Spacer(),
                SizedBox(
                  height: 24,
                  width: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: accentPink,
                    ),
                    tooltip: 'Extract colors from image',
                    onPressed: () async {
                      final List<String> palette =
                          await ColorExtractionService().extractPalette(
                        state.imageFile,
                      );
                      if (palette.isNotEmpty) {
                        cubit.updateStyleColorPalette(palette);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ColorPaletteEditor(
              colors: state.caption.styleDescription.colorPalette,
              onChanged: cubit.updateStyleColorPalette,
              imageFile: state.imageFile,
            ),
          ],
        );
      },
    );
  }
}

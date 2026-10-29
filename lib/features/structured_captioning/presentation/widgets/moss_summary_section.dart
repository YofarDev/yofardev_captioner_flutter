import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../bloc/structured_editor_cubit.dart';
import 'editor_primitives.dart';

/// Right-panel summary editor for MOSS layout captions: meta tag list,
/// canvas selector, palette, and canvas dimensions (positive integers — the
/// stored draft frame, no grid constraint). Changing dimensions rescales
/// stored boxes only via the explicit "Rescale boxes" choice; otherwise the
/// frame moves around pixel-exact geometry. The summary caption itself is
/// edited through the page's Description field.
class MossSummarySection extends StatefulWidget {
  const MossSummarySection({super.key});

  @override
  State<MossSummarySection> createState() => _MossSummarySectionState();
}

class _MossSummarySectionState extends State<MossSummarySection> {
  bool _rescale = false;
  void _setRescale(bool v) => setState(() => _rescale = v);

  @override
  Widget build(BuildContext context) => MossSummarySectionView(
    rescaleBoxes: _rescale,
    onRescaleChanged: _setRescale,
  );
}

/// Stateless view extracted so the section stays testable; [_MossSummarySectionState]
/// owns the intentional-rescale checkbox state.
class MossSummarySectionView extends StatelessWidget {
  const MossSummarySectionView({
    required this.rescaleBoxes,
    required this.onRescaleChanged,
    super.key,
  });

  final bool rescaleBoxes;
  final void Function(bool) onRescaleChanged;

  static const List<String> _canvasOptions = <String>[
    'single',
    'multi_panel',
    'collage',
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final StructuredEditorCubit cubit = context
            .read<StructuredEditorCubit>();
        final String metaText = state.mossMeta.join(', ');
        final bool sizeValid = state.mossWidth > 0 && state.mossHeight > 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            EditorTextField(
              value: metaText,
              maxLines: 2,
              hint: 'meta tags, comma-separated',
              onChanged: (String value) => cubit.updateMossMeta(
                value
                    .split(',')
                    .map((String s) => s.trim())
                    .where((String s) => s.isNotEmpty)
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const Text(
                  'Canvas',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String?>(
                    value: state.mossCanvas,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: panelRaised,
                    style: const TextStyle(color: textPrimary, fontSize: 13),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(child: Text('—')),
                      for (final String c in _canvasOptions)
                        DropdownMenuItem<String?>(value: c, child: Text(c)),
                    ],
                    onChanged: (String? value) => cubit.updateMossCanvas(value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: EditorTextField(
                    value: state.mossWidth.toString(),
                    hint: 'width (px)',
                    onChanged: (String v) => cubit.updateMossSize(
                      width: int.tryParse(v),
                      rescaleBoxes: rescaleBoxes,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: EditorTextField(
                    value: state.mossHeight.toString(),
                    hint: 'height (px)',
                    onChanged: (String v) => cubit.updateMossSize(
                      height: int.tryParse(v),
                      rescaleBoxes: rescaleBoxes,
                    ),
                  ),
                ),
                Icon(
                  sizeValid ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 16,
                  color: sizeValid ? Colors.tealAccent : amberWarn,
                ),
              ],
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: lightPink,
              title: const Text(
                'Rescale boxes on frame change',
                style: TextStyle(fontSize: 12, color: textPrimary),
              ),
              subtitle: const Text(
                'Unchecked: boxes keep their exact pixels (the frame moves '
                'around them). Checked: boxes are scaled to the new frame — '
                'an intentional annotation-frame rescale.',
                style: TextStyle(fontSize: 10, color: textSecondary),
              ),
              value: rescaleBoxes,
              onChanged: (bool? v) => onRescaleChanged(v ?? false),
            ),
          ],
        );
      },
    );
  }
}

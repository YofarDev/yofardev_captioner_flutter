import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../captioning/presentation/widgets/caption_controls.dart';
import '../../../export/presentation/widgets/export_button.dart';
import '../../../main_area/presentation/pages/search_and_replace_widget.dart';
import 'controls_widgets.dart';

class ControlsView extends StatelessWidget {
  const ControlsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildProjectActionsRow(),
            const SizedBox(height: 14),
            _buildGenerationControlPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectActionsRow() => Container(
    padding: const EdgeInsets.only(bottom: 14),
    child: const Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      children: <Widget>[
        PickFolderButton(outlined: true),
        RenameAllFilesButton(outlined: true),
        ExportButton(outlined: true),
        SearchAndReplaceWidget(outlined: true),
      ],
    ),
  );

  Widget _buildGenerationControlPanel() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    decoration: BoxDecoration(
      color: panelDark,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: hairline),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.auto_awesome, size: 13, color: pinkDim),
            SizedBox(width: 6),
            Text(
              'Generate Captions',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textMuted,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        CaptionControls(),
      ],
    ),
  );
}

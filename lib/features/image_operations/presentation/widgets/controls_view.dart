import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'controls_widgets.dart';

/// Toolbar + run-controls column for the tab workspace. Sibling-feature
/// widgets are injected as slots by the composition root (main_area) so this
/// feature does not import captioning/export/main_area.
class ControlsView extends StatelessWidget {
  const ControlsView({
    super.key,
    required this.searchAndReplace,
    required this.captionFiles,
    required this.export,
    required this.captionControls,
  });

  final Widget searchAndReplace;
  final Widget captionFiles;
  final Widget export;
  final Widget captionControls;

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
    child: Wrap(
      spacing: 12.0,
      runSpacing: 8.0,
      children: <Widget>[
        const PickFolderButton(outlined: true),
        const RenameAllFilesButton(outlined: true),
        searchAndReplace,
        captionFiles,
        export,
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.auto_awesome, size: 13, color: pinkDim),
            SizedBox(width: 6),
            Text(
              'Generate Captions',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        captionControls,
      ],
    ),
  );
}

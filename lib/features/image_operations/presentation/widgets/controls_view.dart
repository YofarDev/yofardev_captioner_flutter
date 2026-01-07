import 'package:flutter/material.dart';

import '../../../captioning/presentation/widgets/caption_controls.dart';
import 'controls_widgets.dart';
import '../../../export/presentation/widgets/export_button.dart';
import '../../../llm_config/presentation/pages/llm_config_widget.dart';
import '../../../main_area/presentation/pages/search_and_replace_widget.dart';

class ControlsView extends StatelessWidget {
  const ControlsView({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: <Widget>[
            _buildFirstRow(),
            const SizedBox(height: 8),
            _buildSecondRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstRow() => const Wrap(
    spacing: 16.0,
    runSpacing: 8.0,
    children: <Widget>[
      PickFolderButton(),
      RenameAllFilesButton(),
      SearchAndReplaceWidget(),
      // ConvertAllImagesButton(),
      ExportButton(),
    ],
  );
  Widget _buildSecondRow() => const Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SettingsButton(),
      LlmConfigWidget(),
      SizedBox(width: 32),
      Flexible(child: CaptionControls()),
    ],
  );
}

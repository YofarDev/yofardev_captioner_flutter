import 'package:flutter/material.dart';

import 'caption_controls.dart';
import 'controls_widgets.dart';
import 'export_button.dart';
import 'llm_config_widget.dart';
import 'search_and_replace_widget.dart';

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

  Widget _buildFirstRow() => const Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      PickFolderButton(),
      SizedBox(width: 16),
      RenameAllFilesButton(),
      SizedBox(width: 16),
      SearchAndReplaceWidget(),
      SizedBox(width: 16),
      ConvertAllImagesButton(),
      SizedBox(width: 16),
      ExportButton(),
    ],
  );

  Widget _buildSecondRow() => const Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      ApiSettingsButton(),
      LlmConfigWidget(),
      SizedBox(width: 32),
      Flexible(child: CaptionControls()),
    ],
  );
}

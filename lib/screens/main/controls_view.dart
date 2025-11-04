import 'package:flutter/material.dart';

import 'controls_widgets.dart';
import 'llm_config_widget.dart';
import 'search_and_replace_widget.dart';

class ControlsView extends StatelessWidget {
  const ControlsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

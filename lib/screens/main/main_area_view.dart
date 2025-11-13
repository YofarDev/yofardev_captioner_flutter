import 'package:flutter/material.dart';
import 'caption_text_area.dart';
import 'controls_view.dart';
import 'current_image_view.dart';

class MainAreaView extends StatelessWidget {
  const MainAreaView({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
        CurrentImageView(),
        CaptionTextArea(),
        Spacer(),
        ControlsView(),
      ],
    );
  }
}

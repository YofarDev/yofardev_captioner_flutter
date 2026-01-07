import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../image_list/logic/image_list_cubit.dart';
import '../../../captioning/presentation/widgets/caption_text_area.dart';
import '../../image_operations/presentation/widgets/controls_view.dart';
import 'current_image_view.dart';

class MainAreaView extends StatelessWidget {
  const MainAreaView({super.key});
  @override
  Widget build(BuildContext context) {
            return BlocBuilder<ImageListCubit, ImageListState>(
              builder: (BuildContext context, ImageListState state) {
                if (state.images.isEmpty) {
                  return _buildEmptyView();
                }
                return ListView(
                  children: const <Widget>[
                    CurrentImageView(),
                    CaptionTextArea(),
                    SizedBox(height: 16),
                    ControlsView(),
                  ],
                );
              },
            );  }

  Widget _buildEmptyView() => Opacity(
    opacity: 0.5,
    child: Column(
      children: <Widget>[
        const Spacer(),
        const Text(
          'Yofardev Captioner',
          style: TextStyle(fontSize: 32, fontFamily: 'Orbitron'),
        ),
        const SizedBox(height: 16),
        Image.asset('assets/logo.png', width: 400),
        const Spacer(),
      ],
    ),
  );
}

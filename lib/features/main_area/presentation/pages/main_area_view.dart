import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../caption_search/presentation/widgets/caption_search_bar.dart';
import '../../../captioning/presentation/widgets/caption_text_area.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_operations/presentation/widgets/controls_view.dart';
import 'current_image_view.dart';

class MainAreaView extends StatelessWidget {
  const MainAreaView({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        // Only show empty view when no images are loaded at all
        // (not when search returns no results)
        if (state.images.isEmpty) {
          return _buildEmptyView();
        }
        return Stack(
          children: <Widget>[
            const Column(
              children: <Widget>[
                CurrentImageView(),
                Expanded(child: CaptionTextArea()),
                ControlsView(),
                SizedBox(height: 16),
              ],
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: darkGrey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: const EdgeInsets.all(4),
                child: const CaptionSearchBar(),
              ),
            ),
          ],
        );
      },
    );
  }

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

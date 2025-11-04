import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images/images_cubit.dart';

class CaptionTextArea extends StatelessWidget {
  const CaptionTextArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        if (state.images.isEmpty) {
          return const SizedBox.shrink();
        }

        // Get or create controller for current image
        final ImagesCubit cubit = context.read<ImagesCubit>();
        final TextEditingController controller = cubit.getCaptionController(
          state.currentIndex,
        );

        // Update text only if it differs (avoids cursor reset)
        final String currentCaption = state.images[state.currentIndex].caption;
        if (controller.text != currentCaption) {
          controller.text = currentCaption;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: controller,
              onChanged: (String value) {
                cubit.updateCaption(caption: value.trim());
              },
              maxLines: 10,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images_cubit.dart';

class CaptionWidget extends StatelessWidget {
  const CaptionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        if (state.images.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: TextEditingController(
                text: state.images[state.currentIndex].caption,
              ),
              maxLines: 8,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        );
      },
    );
  }
}

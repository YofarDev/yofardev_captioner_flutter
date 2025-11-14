import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/captioning/captioning_cubit.dart';
import '../../logic/images/image_list_cubit.dart';

class CaptionTextArea extends StatefulWidget {
  const CaptionTextArea({super.key});

  @override
  State<CaptionTextArea> createState() => _CaptionTextAreaState();
}

class _CaptionTextAreaState extends State<CaptionTextArea> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ImageListCubit, ImageListState>(
      listener: (BuildContext context, ImageListState state) {
        if (state.images.isNotEmpty) {
          final String currentCaption =
              state.images[state.currentIndex].caption;
          if (_controller.text != currentCaption) {
            _controller.text = currentCaption;
          }
        }
      },
      child: BlocBuilder<ImageListCubit, ImageListState>(
        builder: (BuildContext context, ImageListState state) {
          if (state.images.isEmpty) {
            return const SizedBox.shrink();
          }
          return BlocBuilder<CaptioningCubit, CaptioningState>(
            builder: (BuildContext context, CaptioningState captioningState) {
              final bool isProcessing =
                  captioningState.status == CaptioningStatus.inProgress;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isProcessing
                        ? Colors.black.withAlpha(20)
                        : Colors.black.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    readOnly: isProcessing,
                    controller: _controller,
                    onChanged: (String value) {
                      context.read<ImageListCubit>().updateCaption(
                        caption: value.trim(),
                      );
                    },
                    maxLines: 10,
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

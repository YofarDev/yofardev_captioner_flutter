import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/captioning/captioning_cubit.dart';
import '../../logic/images_list/image_list_cubit.dart';
import '../../models/app_image.dart';

class CaptionTextArea extends StatefulWidget {
  const CaptionTextArea({super.key});

  @override
  State<CaptionTextArea> createState() => _CaptionTextAreaState();
}

class _CaptionTextAreaState extends State<CaptionTextArea> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

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
          final AppImage currentImage = state.images[state.currentIndex];
          return BlocBuilder<CaptioningCubit, CaptioningState>(
            builder: (BuildContext context, CaptioningState captioningState) {
              final String currentImagePath = currentImage.image.path;
              final bool isThisImageBeingCaptioned =
                  captioningState.currentlyCaptioningImage == currentImagePath;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isThisImageBeingCaptioned
                            ? Colors.black.withAlpha(20)
                            : Colors.black.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        readOnly: isThisImageBeingCaptioned,
                        controller: _controller,
                        onChanged: (String value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();

                          _debounce = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              context.read<ImageListCubit>().updateCaption(
                                caption: value.trim(),
                              );
                            },
                          );
                        },
                        maxLines: 10,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
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
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

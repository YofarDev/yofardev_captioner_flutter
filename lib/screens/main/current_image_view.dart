import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../logic/images/images_cubit.dart';
import '../../models/app_image.dart';
import '../../utils/extensions.dart';
import '../../utils/image_utils.dart';

class CurrentImageView extends StatelessWidget {
  const CurrentImageView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        if (state.images.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            InkWell(
              onTap: () => ImageUtils.openImageWithDefaultApp(
                state.images[state.currentIndex].image.path,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.5,
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Container(color: Colors.black),
                    // Wrap the background image and blur in ClipRect
                    ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.file(
                            state.images[state.currentIndex].image,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: Colors.black.withAlpha(120),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Main image on top
                    Image.file(
                      state.images[state.currentIndex].image,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 16, 32),
              child: _buildSizeInfos(state.images[state.currentIndex]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSizeInfos(AppImage image) {
    if (image.width == -1 || image.height == -1) {
      return Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: Colors.white,
        child: const Text("..."),
      );
    }
    return Text(
      "${image.width}x${image.height} (${image.aspectRatio})",
      style: const TextStyle(fontSize: 11),
    );
  }
}

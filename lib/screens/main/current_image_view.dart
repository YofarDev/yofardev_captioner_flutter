import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../logic/image_operations/image_operations_cubit.dart';
import '../../logic/images_list/image_list_cubit.dart';
import '../../models/app_image.dart';
import '../../utils/image_utils.dart';

class CurrentImageView extends StatelessWidget {
  const CurrentImageView({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        if (state.images.isEmpty) {
          return const SizedBox.shrink();
        }
        final AppImage currentImage = state.images[state.currentIndex];
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
              padding: const EdgeInsets.fromLTRB(0, 4, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (currentImage.captionModel != null &&
                      currentImage.captionTimestamp != null)
                    _buildTimestamp(context, currentImage),
                  const Spacer(),
                  _buildSizeInfos(state.images[state.currentIndex]),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      context.read<ImageOperationsCubit>().cropCurrentImage(
                        context,
                      );
                    },
                    icon: const Icon(Icons.crop),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimestamp(BuildContext context, AppImage currentImage) {
    final DateFormat formatter = DateFormat('d/MM/y • h:mm');
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Tooltip(
        message:
            '🤖 First caption ▶ ${formatter.format(currentImage.captionTimestamp!)}${currentImage.lastModified != null ? '\n✍ Last modified ▶ ${formatter.format(currentImage.lastModified!)}' : ''}',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              '${currentImage.captionModel} • ${timeago.format(currentImage.lastModified ?? currentImage.captionTimestamp!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withAlpha(50),
              ),
            ),
          ],
        ),
      ),
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
      "${image.width}x${image.height} (${ImageUtils.getSimplifiedAspectRatio(image.width, image.height)})",
      style: const TextStyle(fontSize: 11),
    );
  }
}

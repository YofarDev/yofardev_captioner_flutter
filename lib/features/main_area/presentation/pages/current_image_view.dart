import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/widgets/notification_overlay.dart';
import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_operations/data/utils/image_utils.dart';
import '../../../image_operations/logic/image_operations_cubit.dart';

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
                  Tooltip(
                    message: 'Crop this image',
                    child: IconButton(
                      onPressed: () {
                        context.read<ImageOperationsCubit>().cropCurrentImage(
                          context,
                        );
                      },
                      icon: const Icon(
                        Icons.crop,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Duplicate this image and its caption',
                    child: IconButton(
                      onPressed: () async {
                        await context.read<ImageListCubit>().duplicateImage();
                        if (context.mounted) {
                          NotificationOverlay.show(
                            context,
                            message: 'Image duplicated',
                            duration: const Duration(seconds: 2),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.perm_media_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
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
    final String timestampMessage =
        '🤖 First caption ▶ ${formatter.format(currentImage.captionTimestamp!)}${currentImage.lastModified != null ? '\n✍ Last modified ▶ ${formatter.format(currentImage.lastModified!)}' : ''}';
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: GestureDetector(
        onTap: () {
          NotificationOverlay.show(
            context,
            message: timestampMessage,
            duration: const Duration(seconds: 5),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              '${currentImage.captionModel} • ${timeago.format(currentImage.lastModified ?? currentImage.captionTimestamp!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withAlpha(100),
                fontSize: 11,
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

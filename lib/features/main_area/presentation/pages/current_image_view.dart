import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../image_list/presentation/widgets/tag_editor.dart';
import '../../../image_operations/data/utils/image_utils.dart';
import '../../../image_operations/logic/image_operations_cubit.dart';
import '../../../structured_captioning/presentation/widgets/bbox_overlay.dart';
import '../../../structured_captioning/presentation/widgets/ideogram_caption_summary_card.dart';

class CurrentImageView extends StatelessWidget {
  const CurrentImageView({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        final ImageListCubit cubit = context.read<ImageListCubit>();
        final AppImage? currentImage = cubit.currentDisplayedImage;

        // Show "No results" message when search returns no matches
        if (currentImage == null) {
          if (state.images.isNotEmpty && state.searchQuery.isNotEmpty) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.search_off,
                      size: 40,
                      color: textMuted,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Orbitron',
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'No image matches the current filters',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () => cubit.clearSearch(),
                      style: TextButton.styleFrom(foregroundColor: lightPink),
                      child: const Text('Clear search'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            InkWell(
              onTap: () =>
                  ImageUtils.openImageWithDefaultApp(currentImage.image.path),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.4,
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
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
                            currentImage.image,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            cacheWidth:
                                AppConstants.currentImageBackdropDecodeWidth,
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
                    // Main image on top — with bbox overlay if Ideogram JSON caption
                    Builder(
                      builder: (BuildContext context) {
                        final String category =
                            context
                                .read<ImageListCubit>()
                                .state
                                .activeCategory ??
                            'default';
                        final String caption =
                            currentImage.captions[category]?.text ?? '';
                        if (IdeogramCaptionSummaryCard.isIdeogramJson(
                              caption,
                            ) &&
                            BboxElement.parse(caption).isNotEmpty) {
                          return BboxOverlayImage(
                            imageFile: currentImage.image,
                            captionJson: caption,
                          );
                        }
                        return Image.file(
                          currentImage.image,
                          fit: BoxFit.contain,
                        );
                      },
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
                  const SizedBox(width: 8),
                  const TagEditor(),
                  const Spacer(),

                  _buildSizeInfos(currentImage),
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
                        color: textSecondary,
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
                        color: textSecondary,
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
        'First caption\n${formatter.format(currentImage.captionTimestamp!)}${currentImage.lastModified != null ? '\n\nLast modified\n${formatter.format(currentImage.lastModified!)}' : ''}';
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
                color: textMuted,
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
        baseColor: textMuted,
        highlightColor: textSecondary,
        child: const Text('...'),
      );
    }
    return Text(
      '${image.width}x${image.height} (${ImageUtils.getSimplifiedAspectRatio(image.width, image.height)})',
      style: const TextStyle(fontSize: 11, color: textMuted),
    );
  }
}

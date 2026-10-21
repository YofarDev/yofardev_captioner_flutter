import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/app_image.dart';
import '../../../caption_session/caption_session.dart';
import '../bloc/image_list_cubit.dart';
import '../widgets/header_widget.dart';
import '../widgets/image_list_item.dart';

class ImagesListView extends StatelessWidget {
  const ImagesListView({super.key, required this.onAspectRatio});

  final AspectRatioOpener onAspectRatio;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        final ImageListCubit cubit = context.read<ImageListCubit>();
        final List<AppImage> displayedImages = cubit.displayedImages;

        final Widget? dbErrorBanner = state.dbLoadError == null
            ? null
            : Material(
                color: panelRaised,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded, color: amberWarn),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.dbLoadError!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );

        if (displayedImages.isEmpty) {
          return Column(children: <Widget>[?dbErrorBanner]);
        }
        return Column(
          children: <Widget>[
            ?dbErrorBanner,
            HeaderWidget(onAspectRatio: onAspectRatio),
            Container(height: 1, color: hairline),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: displayedImages.length,
                separatorBuilder: (BuildContext context, int index) =>
                    Container(height: 1, color: hairline.withAlpha(120)),
                itemBuilder: (BuildContext context, int index) {
                  final AppImage image = displayedImages[index];
                  return ImageListItem(
                    key: ValueKey<String>(image.image.path),
                    image: image,
                    isSelected: image.id == state.currentImageId,
                    activeCategory: state.activeCategory ?? 'default',
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

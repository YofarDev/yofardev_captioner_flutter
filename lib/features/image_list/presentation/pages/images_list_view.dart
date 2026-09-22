import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/app_image.dart';
import '../../logic/image_list_cubit.dart';
import '../widgets/header_widget.dart';
import '../widgets/image_list_item.dart';

class ImagesListView extends StatelessWidget {
  const ImagesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        final ImageListCubit cubit = context.read<ImageListCubit>();
        final List<AppImage> displayedImages = cubit.displayedImages;

        if (displayedImages.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: <Widget>[
            const HeaderWidget(),
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

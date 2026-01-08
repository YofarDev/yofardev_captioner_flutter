import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/image_list_cubit.dart';
import '../widgets/header_widget.dart';
import '../widgets/image_list_item.dart';

class ImagesListView extends StatelessWidget {
  const ImagesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        if (state.images.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: <Widget>[
            const HeaderWidget(),
            Container(height: 1, color: Colors.black.withAlpha(80)),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.images.length,
                itemBuilder: (BuildContext context, int index) {
                  return ImageListItem(
                    key: ValueKey<String>(state.images[index].image.path),
                    image: state.images[index],
                    index: index,
                    isSelected: index == state.currentIndex,
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

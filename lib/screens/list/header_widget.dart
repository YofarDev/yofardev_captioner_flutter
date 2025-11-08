import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images/images_cubit.dart';
import '../../models/app_image.dart';
import '../main/aspect_ratio_dialog.dart';
import 'sort_by_widget.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return const AspectRatioDialog();
              },
            );
            context.read<ImagesCubit>().state.images.forEach(
              (AppImage image) {},
            );
          },
          child: ColoredBox(
            color: Colors.black.withAlpha(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Text(state.folderPath!, style: const TextStyle(fontSize: 9)),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Text(
                        "${state.images.length} images / ${state.images.length - state.emptyCaptions} captions",
                        style: const TextStyle(fontSize: 9),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: state.folderPath == null
                            ? null
                            : () {
                                context.read<ImagesCubit>().onFolderPicked(
                                  state.folderPath!,
                                );
                              },
                      ),
                    ],
                  ),
                  const SortByWidget(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

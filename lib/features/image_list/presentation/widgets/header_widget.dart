import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/image_list_cubit.dart';
import '../../data/models/app_image.dart';
import '../../../image_operations/presentation/pages/aspect_ratio_dialog.dart';
import 'sort_by_widget.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return const AspectRatioDialog();
              },
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
                  Row(
                    children: <Widget>[
                      Text(
                        "${state.images.length} images / ${state.images.where((AppImage image) => image.caption.isNotEmpty).length} captions",
                        style: const TextStyle(fontSize: 11),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: state.folderPath == null
                            ? null
                            : () {
                                context.read<ImageListCubit>().onFolderPicked(
                                  state.folderPath!,
                                  force: true,
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/extensions.dart';
import '../../../image_operations/presentation/pages/aspect_ratio_dialog.dart';
import '../../data/models/app_image.dart';
import '../../logic/image_list_cubit.dart';
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Text(state.folderPath!, style: const TextStyle(fontSize: 9)),
                  Row(
                    children: <Widget>[
                      Image.asset('assets/icons/image.png', width: 16),
                      const SizedBox(width: 8),
                      Text(
                        "${state.images.length} images / ${state.images.where((AppImage image) => image.caption.isNotEmpty).length} captions",
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Reload current folder',
                        child: InkWell(
                          onTap: state.folderPath == null
                              ? null
                              : () {
                                  context.read<ImageListCubit>().onFolderPicked(
                                    state.folderPath!,
                                    force: true,
                                  );
                                },
                          child: const Icon(Icons.refresh, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Image.asset('assets/icons/folder.png', width: 16),
                      const SizedBox(width: 8),

                      Text(
                        context
                            .read<ImageListCubit>()
                            .getTotalImagesSize()
                            .readableFileSize,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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

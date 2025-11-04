import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images/images_cubit.dart';
import '../../models/app_image.dart';
import '../../res/app_colors.dart';
import '../../utils/extensions.dart';
import 'header_widget.dart';

class ImagesListView extends StatelessWidget {
  const ImagesListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        if (state.images.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: <Widget>[
            const HeaderWidget(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.images.length,
                itemBuilder: (BuildContext context, int index) {
                  final AppImage image = state.images[index];
                  return InkWell(
                    onTap: () =>
                        context.read<ImagesCubit>().onImageSelected(index),
                    child: ColoredBox(
                      color: index == state.currentIndex
                          ? Colors.white.withAlpha(50)
                          : image.caption.isEmpty
                          ? lightPink.withAlpha(20)
                          : Colors.transparent,
                      child: Row(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                image.image,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  image.image.path.split('/').last,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: index == state.currentIndex
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  "(${image.image.lengthSync().readableFileSize})",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: index == state.currentIndex
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Remove Image'),
                                    content: const Text(
                                      'Are you sure you want to remove this image and its caption?',
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: const Text('Cancel'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('Remove'),
                                        onPressed: () {
                                          context
                                              .read<ImagesCubit>()
                                              .removeImage(index);
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
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

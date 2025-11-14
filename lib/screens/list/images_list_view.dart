import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images_list/image_list_cubit.dart';
import '../../models/app_image.dart';
import '../../res/app_colors.dart';
import '../../res/app_constants.dart';
import '../../utils/extensions.dart';
import 'header_widget.dart';

class ImagesListView extends StatelessWidget {
  const ImagesListView({super.key});

  String _getSizeCategory(AppImage image) {
    if (image.width > 0 && image.height > 0) {
      final int minSize = image.width < image.height
          ? image.width
          : image.height;
      if (minSize < 512) {
        return '<512';
      }
      if (minSize < 768) {
        return '<768';
      }
      if (minSize < 1024) {
        return '<1024';
      }
    }
    return '';
  }

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
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.images.length,
                itemBuilder: (BuildContext context, int index) {
                  final AppImage image = state.images[index];
                  final String sizeCategory = _getSizeCategory(image);
                  final bool hasPresetRatio = AppConstants.aspectRatioStrings
                      .contains(image.aspectRatio);
                  return InkWell(
                    onTap: () =>
                        context.read<ImageListCubit>().onImageSelected(index),
                    child: ColoredBox(
                      color: index == state.currentIndex
                          ? Colors.white.withAlpha(50)
                          : image.caption.isEmpty
                          ? lightPink.withAlpha(20)
                          : Colors.transparent,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: !hasPresetRatio
                                        ? Border.all(
                                            color: Colors.red[400]!,
                                            width: 2,
                                          )
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
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
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Flexible(
                                          child: Text(
                                            image.image.path.split('/').last,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  index == state.currentIndex
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (image.error != null)
                                          Row(
                                            children: <Widget>[
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8.0,
                                                ),
                                                child: Tooltip(
                                                  message: image.error,
                                                  child: const Icon(
                                                    Icons.error,
                                                    color: Colors.red,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
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
                              if (image.caption.isNotEmpty)
                                Tooltip(
                                  message: 'Copy caption',
                                  child: IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: image.caption),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Caption copied to clipboard',
                                          ),
                                        ),
                                      );
                                    },
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
                                                  .read<ImageListCubit>()
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
                          if (sizeCategory.isNotEmpty)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Text(
                                sizeCategory,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white.withAlpha(80),
                                ),
                              ),
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

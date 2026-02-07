import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../../image_operations/presentation/pages/aspect_ratio_dialog.dart';
import '../../data/models/app_image.dart';
import '../../logic/image_list_cubit.dart';
import '../utils/folder_utils.dart';
import 'sort_by_widget.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  static const double _iconSize = 12;
  static const double _spacing = 8.0;
  static const double _fontSize = 10;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 16.0,
    vertical: 8,
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImageListCubit, ImageListState>(
      builder: (BuildContext context, ImageListState state) {
        return InkWell(
          onTap: () => _showAspectRatioDialog(context),
          child: ColoredBox(
            color: Colors.black.withAlpha(50),
            child: Padding(
              padding: _padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildFolderInfoRow(context, state),
                  const SizedBox(height: 6),
                  _buildImageCountRow(state.images, state.activeCategory),
                  const SizedBox(height: 6),
                  _buildWordsPerCaptionRow(context),
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

  void _showAspectRatioDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => const AspectRatioDialog(),
    );
  }

  Widget _buildFolderInfoRow(BuildContext context, ImageListState state) {
    final ImageListCubit cubit = context.read<ImageListCubit>();
    return Row(
      children: <Widget>[
        InkWell(
          onTap: () =>
              FolderUtils.openFolderWithDefaultApp(state.folderPath ?? ''),
          child: Row(
            children: <Widget>[
              Image.asset('assets/icons/folder.png', width: _iconSize),
              const SizedBox(width: _spacing),
              Text(
                cubit.getTotalImagesSize().readableFileSize,
                style: const TextStyle(
                  fontSize: _fontSize,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Tooltip(
          message: 'Reload current folder',
          child: InkWell(
            onTap: state.folderPath == null
                ? null
                : () => cubit.onFolderPicked(state.folderPath!, force: true),
            child: const Icon(Icons.refresh, size: _iconSize),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCountRow(
    List<AppImage> images,
    String? activeCategory,
  ) {
    final String category = activeCategory ?? 'default';
    final int captionCount = images
        .where((AppImage image) =>
            (image.captions[category]?.text ?? '').isNotEmpty)
        .length;

    return Row(
      children: <Widget>[
        Image.asset('assets/icons/image.png', width: _iconSize),
        const SizedBox(width: _spacing),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: _fontSize, color: Colors.white, fontFamily: 'Inter'),
            children: <TextSpan>[
              TextSpan(text: '$captionCount / ${images.length} captions'),
              if (activeCategory != null) ...<TextSpan>[
                const TextSpan(text: ' ('),
                TextSpan(
                  text: activeCategory,
                  style: TextStyle(
                    color: lightPink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ')'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWordsPerCaptionRow(BuildContext context) {
    final String avgWords = context
        .read<ImageListCubit>()
        .getAverageWordsPerCaption()
        .toStringAsFixed(1);

    return Tooltip(
      message: 'Average words per caption',
      child: Row(
        children: <Widget>[
          Image.asset('assets/icons/words.png', width: _iconSize),
          const SizedBox(width: _spacing),
          Text(
            "$avgWords words / caption",
            style: const TextStyle(fontSize: _fontSize),
          ),
        ],
      ),
    );
  }
}

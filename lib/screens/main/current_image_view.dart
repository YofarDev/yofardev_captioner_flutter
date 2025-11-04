import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../logic/images_cubit.dart';
import '../../models/app_image.dart';
import '../../utils/extensions.dart';
import '../../utils/image_utils.dart';

class CurrentImageView extends StatelessWidget {
  const CurrentImageView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        if (state.images.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              GestureDetector(
                onTap: () => ImageUtils.openImageWithDefaultApp(
                  state.images[state.currentIndex].image.path,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.5,
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: Image.file(
                    state.images[state.currentIndex].image,
                    //width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              _buildSizeInfos(state.images[state.currentIndex]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSizeInfos(AppImage image) {
    if (image.width == -1 || image.height == -1) {
      return Shimmer.fromColors(
        baseColor: Colors.grey,
        highlightColor: Colors.white,
        child: const Text("..."),
      );
    }
    return Text(
      "${image.width}x${image.height} (${image.aspectRatio})",
      style: const TextStyle(fontSize: 10),
    );
  }
}

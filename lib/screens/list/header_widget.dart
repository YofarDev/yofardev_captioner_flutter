import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images/images_cubit.dart';
import 'sort_by_widget.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        return ColoredBox(
          color: Colors.black.withAlpha(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Text(state.folderPath!, style: const TextStyle(fontSize: 9)),
                const SizedBox(height: 8),
                Text(
                  "${state.images.length} images / ${state.images.length - state.emptyCaptions} captions",
                  style: const TextStyle(fontSize: 9),
                ),
                const SortByWidget(),
              ],
            ),
          ),
        );
      },
    );
  }
}

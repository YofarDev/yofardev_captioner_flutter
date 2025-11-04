import 'package:flutter/material.dart';

import '../res/app_colors.dart';
import 'list/images_list_view.dart';
import 'main/main_area_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            color: darkGrey,
            height: double.infinity,
            width: 240,
            child: const ImagesListView(),
          ),
          Expanded(
            child: ColoredBox(color: lightGrey, child: const MainAreaView()),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:ui';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import '../logic/images/image_list_cubit.dart';
import '../res/app_colors.dart';
import 'list/images_list_view.dart';
import 'main/main_area_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDragging = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DropTarget(
        onDragEntered: (DropEventDetails details) {
          setState(() => _isDragging = true);
        },
        onDragExited: (DropEventDetails details) {
          setState(() => _isDragging = false);
        },
        onDragDone: (DropDoneDetails details) {
          setState(() => _isDragging = false);
          if (details.files.isNotEmpty) {
            final DropItem file = details.files.first;
            final String filePath = file.path;
            final FileSystemEntityType entity = FileSystemEntity.typeSync(
              filePath,
            );
            String folderPath = "";
            if (entity == FileSystemEntityType.directory) {
              folderPath = filePath;
            } else {
              folderPath = path.dirname(filePath);
            }
            context.read<ImageListCubit>().onFolderPicked(folderPath);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  color: darkGrey,
                  height: double.infinity,
                  width: 240,
                  child: const ImagesListView(),
                ),
                Expanded(
                  child: ColoredBox(
                    color: lightGrey,
                    child: const MainAreaView(),
                  ),
                ),
              ],
            ),
            if (_isDragging)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withAlpha(150)),
              ),
            if (_isDragging)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 64,
                    vertical: 128,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white),
                  ),
                  child: const Text(
                    "Drag a file or folder here",
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

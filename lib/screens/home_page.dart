import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;

import '../logic/images_list/image_list_cubit.dart';
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
  final FocusNode _focusNode = FocusNode();
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          final bool isControlPressed =
              HardwareKeyboard.instance.isControlPressed;
          if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyS) {
            context.read<ImageListCubit>().saveChanges();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            context.read<ImageListCubit>().nextImage();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            context.read<ImageListCubit>().previousImage();
          }
        }
      },
      child: Scaffold(
        body: DropTarget(
          key: const Key("DropTarget"),
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
                    color: lightGrey,
                    height: double.infinity,
                    width: 240,
                    child: const ImagesListView(),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: darkGrey,
                      child: const MainAreaView(),
                    ),
                  ),
                ],
              ),
              IgnorePointer(
                ignoring: !_isDragging,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isDragging ? 1.0 : 0.0,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.black.withAlpha(150)),
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: !_isDragging,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isDragging ? 1.0 : 0.0,
                  child: Center(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logic/images_list/image_list_cubit.dart';
import '../../core/constants/app_colors.dart';
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
  static const MethodChannel _channel = MethodChannel(
    'dev.yofardev.io/open_file',
  );

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'setFilePath') {
        final String path = call.arguments as String;
        context.read<ImageListCubit>().onFileOpened(path);
      }
    });
  }

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
              final String filePath = details.files.first.path;
              final FileSystemEntityType entity = FileSystemEntity.typeSync(
                filePath,
              );
              if (entity == FileSystemEntityType.directory) {
                context.read<ImageListCubit>().onFolderPicked(filePath);
              } else {
                context.read<ImageListCubit>().onFileOpened(filePath);
              }
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

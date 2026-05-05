import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../features/image_list/logic/image_list_cubit.dart';
import '../../../features/tab_manager/data/models/app_tab.dart';
import '../../../features/tab_manager/logic/tab_manager_cubit.dart';
import '../../../features/tab_manager/presentation/widgets/tab_bar_widget.dart';
import '../../../features/tab_manager/presentation/widgets/tab_content.dart';

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
  bool _filePending = false;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'setFilePath') {
        final String path = call.arguments as String;
        _filePending = true;
        _handleFileOpened(path);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_filePending) {
        _initTabs();
      }
    });
  }

  Future<void> _initTabs() async {
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    final String tabId = tabManager.state.activeTab.id;
    // Wait for TabContent to register its cubit
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final ImageListCubit? cubit = tabManager.getCubitForTab(tabId);
    if (cubit != null) {
      cubit.onInit();
    }
  }

  void _handleFileOpened(String filePath) {
    final String folderPath = p.dirname(filePath);
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    final AppTab? existing = tabManager.findTabByFolderPath(folderPath);

    if (existing != null) {
      tabManager.switchTab(tabManager.state.tabs.indexOf(existing));
      final ImageListCubit? cubit = tabManager.getCubitForTab(existing.id);
      if (cubit != null) {
        cubit.onFileOpened(filePath);
      }
    } else {
      tabManager.addTab(folderPath);
      // Wait for new TabContent to register
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        final ImageListCubit? cubit = tabManager.getCubitForTab(
          tabManager.activeTabId,
        );
        if (cubit != null) {
          cubit.onFileOpened(filePath);
        }
      });
    }
  }

  void _handleFolderPicked(String folderPath) {
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    final AppTab activeTab = tabManager.state.activeTab;

    if (activeTab.folderPath == null) {
      tabManager.updateTabFolderPath(activeTab.id, folderPath);
      final ImageListCubit? cubit = tabManager.getCubitForTab(activeTab.id);
      if (cubit != null) {
        cubit.onFolderPicked(folderPath);
      }
    } else {
      tabManager.addTab(folderPath);
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        final ImageListCubit? cubit = tabManager.getCubitForTab(
          tabManager.activeTabId,
        );
        if (cubit != null) {
          cubit.onFolderPicked(folderPath);
        }
      });
    }
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
          final TabManagerCubit tabManager = context.read<TabManagerCubit>();
          final ImageListCubit? cubit = tabManager.getCubitForTab(
            tabManager.activeTabId,
          );
          if (cubit == null) return;

          if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyS) {
            cubit.saveChanges();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            cubit.nextImage();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            cubit.previousImage();
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
                _handleFolderPicked(filePath);
              } else {
                _handleFileOpened(filePath);
              }
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Column(
                children: <Widget>[
                  const TabBarWidget(),
                  Expanded(
                    child: BlocBuilder<TabManagerCubit, TabManagerState>(
                      builder: (BuildContext context, TabManagerState state) {
                        return IndexedStack(
                          index: state.activeTabIndex,
                          children: state.tabs.map((AppTab tab) {
                            return TabContent(
                              key: ValueKey<String>(tab.id),
                              tabId: tab.id,
                            );
                          }).toList(),
                        );
                      },
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

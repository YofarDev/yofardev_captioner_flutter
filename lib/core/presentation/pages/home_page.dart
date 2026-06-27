import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../../core/services/cache_service.dart';
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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
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

  Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = 'v${info.version}');
    }
  }

  Future<void> _initTabs() async {
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    final List<String> savedPaths = await CacheService.loadTabPaths();

    // Wait for initial TabContent to register its cubit
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (savedPaths.isEmpty) {
      // No saved tabs — try loading last folder into default tab
      final String tabId = tabManager.state.activeTab.id;
      final ImageListCubit? cubit = tabManager.getCubitForTab(tabId);
      if (cubit != null) {
        final String? lastPath = await CacheService.loadFolderPath();
        if (lastPath != null) {
          tabManager.updateTabFolderPath(tabId, lastPath);
          cubit.onInit(folderPath: lastPath);
        }
      }
      return;
    }

    // Restore saved tabs
    final int savedIndex = await CacheService.loadActiveTabIndex();

    // Load first tab into the default empty tab
    final String defaultTabId = tabManager.state.activeTab.id;
    final ImageListCubit? defaultCubit = tabManager.getCubitForTab(
      defaultTabId,
    );
    if (defaultCubit != null && savedPaths.isNotEmpty) {
      tabManager.updateTabFolderPath(defaultTabId, savedPaths.first);
      defaultCubit.onInit(folderPath: savedPaths.first);
    }

    // Create additional tabs for remaining paths
    for (int i = 1; i < savedPaths.length; i++) {
      tabManager.addTab(savedPaths[i]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final String newTabId = tabManager.activeTabId;
      final ImageListCubit? cubit = tabManager.getCubitForTab(newTabId);
      if (cubit != null) {
        cubit.onInit(folderPath: savedPaths[i]);
      }
    }

    // Restore active tab index
    if (savedIndex < savedPaths.length) {
      tabManager.switchTab(savedIndex);
    }
  }

  Future<void> _handleFileOpened(String filePath) async {
    final String folderPath = p.dirname(filePath);
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    final AppTab? existing = tabManager.findTabByFolderPath(folderPath);

    if (existing != null) {
      tabManager.switchTab(tabManager.state.tabs.indexOf(existing));
      final ImageListCubit? cubit = await _waitForCubit(existing.id);
      if (cubit != null) {
        cubit.onFileOpened(filePath);
      }
      return;
    }

    final AppTab activeTab = tabManager.state.activeTab;
    if (activeTab.folderPath == null) {
      tabManager.updateTabFolderPath(activeTab.id, folderPath);
      final ImageListCubit? cubit = await _waitForCubit(activeTab.id);
      if (cubit != null) {
        cubit.onFileOpened(filePath);
      }
    } else {
      tabManager.addTab(folderPath);
      final ImageListCubit? cubit = await _waitForCubit(tabManager.activeTabId);
      if (cubit != null) {
        cubit.onFileOpened(filePath);
      }
    }
  }

  Future<ImageListCubit?> _waitForCubit(String tabId) async {
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    for (int i = 0; i < 10; i++) {
      final ImageListCubit? cubit = tabManager.getCubitForTab(tabId);
      if (cubit != null) return cubit;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  Future<void> _handleFolderPicked(String folderPath) async {
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    final AppTab activeTab = tabManager.state.activeTab;

    if (activeTab.folderPath == null) {
      tabManager.updateTabFolderPath(activeTab.id, folderPath);
      final ImageListCubit? cubit = await _waitForCubit(activeTab.id);
      if (cubit != null) {
        cubit.onFolderPicked(folderPath);
      }
    } else {
      tabManager.addTab(folderPath);
      final ImageListCubit? cubit = await _waitForCubit(tabManager.activeTabId);
      if (cubit != null) {
        cubit.onFolderPicked(folderPath);
      }
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
                        // ponytail: not IndexedStack — it wraps each child in a
                        // keyless Visibility, so removing a tab reconciles by slot
                        // and re-inflates (wiping state of) every tab after it.
                        // Keyed Offstage as the direct Stack child is matched by
                        // key, so closing a tab preserves the remaining cubits.
                        return Stack(
                          fit: StackFit.expand,
                          children: List<Widget>.generate(state.tabs.length, (
                            int index,
                          ) {
                            final AppTab tab = state.tabs[index];
                            return Offstage(
                              key: ValueKey<String>(tab.id),
                              offstage: index != state.activeTabIndex,
                              child: TabContent(tabId: tab.id),
                            );
                          }),
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
              Positioned(
                bottom: 4,
                right: 8,
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).hintColor,
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

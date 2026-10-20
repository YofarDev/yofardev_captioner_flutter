import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../../features/image_list/domain/services/caption_session_service.dart';
import '../../../features/tab_manager/data/models/app_tab.dart';
import '../../../features/tab_manager/logic/tab_manager_cubit.dart';
import '../../../features/tab_manager/presentation/widgets/tab_bar_widget.dart';
import '../../../features/tab_manager/presentation/widgets/tab_content.dart';
import '../../constants/app_colors.dart';
import '../../services/cache_service.dart';
import '../../widgets/rive_animations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.cacheService});

  final CacheService cacheService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CacheService get _cacheService => widget.cacheService;
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
    final List<String> savedPaths = await _cacheService.loadTabPaths();

    if (savedPaths.isEmpty) {
      // No saved tabs — try loading last folder into default tab
      final String tabId = tabManager.state.activeTab.id;
      final String? lastPath = await _cacheService.loadFolderPath();
      if (lastPath != null) {
        tabManager.updateTabFolderPath(tabId, lastPath);
        // Sessions are created synchronously with tabs — no waiting needed.
        tabManager.sessionFor(tabId).onInit(folderPath: lastPath);
      }
      return;
    }

    // Restore saved tabs
    final int savedIndex = await _cacheService.loadActiveTabIndex();

    // Load first tab into the default empty tab
    final String defaultTabId = tabManager.state.activeTab.id;
    tabManager.updateTabFolderPath(defaultTabId, savedPaths.first);
    tabManager.sessionFor(defaultTabId).onInit(folderPath: savedPaths.first);

    // Create additional tabs for remaining paths (sessions exist as soon as
    // addTab returns).
    for (int i = 1; i < savedPaths.length; i++) {
      tabManager.addTab(savedPaths[i]);
      tabManager
          .sessionFor(tabManager.activeTabId)
          .onInit(folderPath: savedPaths[i]);
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
      tabManager.sessionFor(existing.id).onFileOpened(filePath);
      return;
    }

    final AppTab activeTab = tabManager.state.activeTab;
    if (activeTab.folderPath == null) {
      tabManager.updateTabFolderPath(activeTab.id, folderPath);
      tabManager.sessionFor(activeTab.id).onFileOpened(filePath);
    } else {
      tabManager.addTab(folderPath);
      tabManager.sessionFor(tabManager.activeTabId).onFileOpened(filePath);
    }
  }

  Future<void> _handleFolderPicked(String folderPath) async {
    final TabManagerCubit tabManager = context.read<TabManagerCubit>();
    final AppTab activeTab = tabManager.state.activeTab;

    if (activeTab.folderPath == null) {
      tabManager.updateTabFolderPath(activeTab.id, folderPath);
      tabManager.sessionFor(activeTab.id).onFolderPicked(folderPath);
    } else {
      tabManager.addTab(folderPath);
      tabManager.sessionFor(tabManager.activeTabId).onFolderPicked(folderPath);
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
          final CaptionSessionService session = tabManager.sessionFor(
            tabManager.activeTabId,
          );

          if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyS) {
            session.saveChanges();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            session.nextImage();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            session.previousImage();
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
                    child: Container(color: Colors.black.withAlpha(140)),
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
                        horizontal: 56,
                        vertical: 40,
                      ),
                      decoration: BoxDecoration(
                        color: pinkSurface.withAlpha(220),
                        borderRadius: BorderRadius.circular(radiusLg),
                        border: Border.all(color: accentPink, width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const RiveDropHint(),
                          const SizedBox(height: 14),
                          const Text(
                            'Drop to open',
                            style: TextStyle(
                              color: lightPink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A folder of images, or a single image',
                            style: TextStyle(
                              color: lightPink.withAlpha(150),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 16,
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).hintColor.withAlpha(80),
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

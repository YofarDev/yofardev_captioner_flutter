import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/tab_manager/data/models/app_tab.dart';
import 'package:yofardev_captioner/features/tab_manager/logic/tab_manager_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // Mock window_manager channel (TabManagerCubit calls windowManager.setTitle)
  const MethodChannel windowManagerChannel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        windowManagerChannel,
        (MethodCall methodCall) async => null,
      );

  group('Tab routing coordination', () {
    late TabManagerCubit tabManager;
    late ImageListCubit cubit1;
    late ImageListCubit cubit2;

    setUp(() {
      tabManager = TabManagerCubit();
      cubit1 = ImageListCubit();
      cubit2 = ImageListCubit();
    });

    tearDown(() {
      cubit2.close();
      cubit1.close();
      tabManager.close();
    });

    group('folder picked routing', () {
      test('loads folder into empty active tab', () {
        final String tabId = tabManager.state.activeTab.id;
        tabManager.registerTabCubit(tabId, cubit1);

        expect(tabManager.state.activeTab.folderPath, isNull);

        tabManager.updateTabFolderPath(tabId, '/photos');
        final ImageListCubit? cubit = tabManager.getCubitForTab(tabId);
        expect(cubit, isNotNull);
        expect(cubit, same(cubit1));

        expect(tabManager.state.activeTab.folderPath, '/photos');
        expect(tabManager.state.activeTab.displayName, 'photos');
      });

      test('creates new tab when active tab has folder', () {
        // Setup: first tab has a folder
        final String tabId = tabManager.state.activeTab.id;
        tabManager.registerTabCubit(tabId, cubit1);
        tabManager.updateTabFolderPath(tabId, '/photos');

        // Simulate: user picks another folder -> new tab created
        tabManager.addTab('/videos');
        final String newTabId = tabManager.activeTabId;
        tabManager.registerTabCubit(newTabId, cubit2);

        expect(tabManager.state.tabs.length, 2);
        expect(tabManager.state.activeTab.folderPath, '/videos');
        expect(tabManager.state.activeTab.displayName, 'videos');
      });
    });

    group('file opened routing', () {
      test('activates existing tab when folder already open', () {
        // Setup: two tabs, one with /photos
        tabManager.addTab('/photos');
        tabManager.registerTabCubit(tabManager.state.tabs[0].id, cubit1);
        tabManager.registerTabCubit(tabManager.state.tabs[1].id, cubit2);

        // Switch away from /photos tab
        tabManager.switchTab(0);
        expect(tabManager.state.activeTabIndex, 0);

        // Simulate: open file in /photos -> should activate tab 1
        final AppTab? existing = tabManager.findTabByFolderPath('/photos');
        expect(existing, isNotNull);
        tabManager.switchTab(tabManager.state.tabs.indexOf(existing!));

        expect(tabManager.state.activeTabIndex, 1);
      });

      test('creates new tab when folder not open', () {
        final String tabId = tabManager.state.activeTab.id;
        tabManager.registerTabCubit(tabId, cubit1);
        tabManager.updateTabFolderPath(tabId, '/photos');

        // Simulate: open file in /videos -> not open yet
        final AppTab? existing = tabManager.findTabByFolderPath('/videos');
        expect(existing, isNull);

        tabManager.addTab('/videos');
        expect(tabManager.state.tabs.length, 2);
        expect(tabManager.state.activeTab.folderPath, '/videos');
      });

      test('loads into empty active tab instead of creating new one', () {
        // Active tab is empty (no folder)
        final String tabId = tabManager.state.activeTab.id;
        tabManager.registerTabCubit(tabId, cubit1);
        expect(tabManager.state.activeTab.folderPath, isNull);

        // Simulate: file opened, its folder doesn't match any tab
        final AppTab? existing = tabManager.findTabByFolderPath('/photos');
        expect(existing, isNull);

        // Should load into active tab instead of creating new
        final AppTab activeTab = tabManager.state.activeTab;
        if (activeTab.folderPath == null) {
          tabManager.updateTabFolderPath(activeTab.id, '/photos');
        } else {
          tabManager.addTab('/photos');
        }

        expect(tabManager.state.tabs.length, 1); // No new tab created
        expect(tabManager.state.activeTab.folderPath, '/photos');
      });
    });

    group('tab lifecycle', () {
      test('cubit registry tracks active tab correctly', () {
        final String defaultTabId = tabManager.state.activeTab.id;
        tabManager.registerTabCubit(defaultTabId, cubit1);
        tabManager.addTab('/photos');
        final String photosTabId = tabManager.activeTabId;
        tabManager.registerTabCubit(photosTabId, cubit2);

        expect(tabManager.getCubitForTab(defaultTabId), same(cubit1));
        expect(tabManager.getCubitForTab(photosTabId), same(cubit2));
      });

      test('unregistering cubit on tab close', () {
        final String defaultTabId = tabManager.state.activeTab.id;
        tabManager.registerTabCubit(defaultTabId, cubit1);
        tabManager.addTab('/photos');
        final String photosTabId = tabManager.activeTabId;
        tabManager.registerTabCubit(photosTabId, cubit2);

        tabManager.closeTab(photosTabId);
        // cubit2 should be unregistered by the widget
        tabManager.unregisterTabCubit(photosTabId);
        expect(tabManager.getCubitForTab(photosTabId), isNull);
        expect(tabManager.getCubitForTab(defaultTabId), same(cubit1));
      });
    });

    group('edge cases', () {
      test('findTabByFolderPath with multiple folders', () {
        tabManager.addTab('/photos/vacation');
        tabManager.addTab('/photos/work');
        tabManager.addTab('/videos');

        final AppTab? result = tabManager.findTabByFolderPath('/photos/work');
        expect(result, isNotNull);
        expect(result!.displayName, 'work');
      });

      test('activateOrAddTab is idempotent', () {
        tabManager.addTab('/photos');
        tabManager.switchTab(0);

        tabManager.activateOrAddTab('/photos');
        expect(tabManager.state.activeTabIndex, 1);
        expect(tabManager.state.tabs.length, 2);

        // Calling again should not create another tab
        tabManager.activateOrAddTab('/photos');
        expect(tabManager.state.tabs.length, 2);
      });

      test('closing all extra tabs returns to single tab', () {
        tabManager.addTab('/first');
        tabManager.addTab('/second');

        expect(tabManager.state.tabs.length, 3);

        // Close tabs in reverse order
        tabManager.closeTab(tabManager.state.tabs[2].id);
        tabManager.closeTab(tabManager.state.tabs[1].id);

        expect(tabManager.state.tabs.length, 1);
        expect(tabManager.state.activeTabIndex, 0);
      });
    });
  });
}

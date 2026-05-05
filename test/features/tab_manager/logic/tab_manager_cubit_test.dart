import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/features/tab_manager/data/models/app_tab.dart';
import 'package:yofardev_captioner/features/tab_manager/logic/tab_manager_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SharedPreferences.setMockInitialValues(<String, Object>{});

  const MethodChannel channel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

  group('TabManagerCubit', () {
    late TabManagerCubit cubit;

    setUp(() {
      cubit = TabManagerCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has one default tab', () {
      expect(cubit.state.tabs.length, 1);
      expect(cubit.state.tabs.first.id, 'default');
      expect(cubit.state.tabs.first.displayName, 'New Tab');
      expect(cubit.state.tabs.first.folderPath, isNull);
      expect(cubit.state.activeTabIndex, 0);
    });

    group('addTab', () {
      test('creates new tab and switches to it', () {
        cubit.addTab('/path/to/images');

        expect(cubit.state.tabs.length, 2);
        expect(cubit.state.activeTabIndex, 1);
        expect(cubit.state.activeTab.folderPath, '/path/to/images');
        expect(cubit.state.activeTab.displayName, 'images');
      });

      test('creates tab with default name when folderPath is null', () {
        cubit.addTab(null);

        expect(cubit.state.tabs.length, 2);
        expect(cubit.state.activeTab.displayName, 'New Tab');
        expect(cubit.state.activeTab.folderPath, isNull);
      });
    });

    group('switchTab', () {
      test('changes active index', () {
        cubit.addTab('/first');
        cubit.addTab('/second');

        expect(cubit.state.activeTabIndex, 2);

        cubit.switchTab(1);
        expect(cubit.state.activeTabIndex, 1);
        expect(cubit.state.activeTab.folderPath, '/first');

        cubit.switchTab(0);
        expect(cubit.state.activeTabIndex, 0);
      });

      test('ignores invalid negative index', () {
        cubit.switchTab(-1);
        expect(cubit.state.activeTabIndex, 0);
      });

      test('ignores index beyond bounds', () {
        cubit.switchTab(99);
        expect(cubit.state.activeTabIndex, 0);
      });
    });

    group('closeTab', () {
      test('removes tab and adjusts index', () {
        cubit.addTab('/first');
        cubit.addTab('/second');

        final String secondTabId = cubit.state.tabs[2].id;
        cubit.closeTab(secondTabId);

        expect(cubit.state.tabs.length, 2);
        expect(cubit.state.activeTabIndex, 1);
      });

      test('cannot remove last tab', () {
        expect(cubit.state.tabs.length, 1);

        cubit.closeTab('default');

        expect(cubit.state.tabs.length, 1);
      });

      test('adjusts active index when closing tab before active', () {
        cubit.addTab('/first');
        cubit.addTab('/second');

        // Active tab is at index 2 (second), close tab at index 1 (first)
        final String firstTabId = cubit.state.tabs[1].id;
        cubit.closeTab(firstTabId);

        expect(cubit.state.tabs.length, 2);
        expect(cubit.state.activeTabIndex, 1);
        expect(cubit.state.activeTab.folderPath, '/second');
      });

      test('adjusts active index when closing the active tab at the end', () {
        cubit.addTab('/first');

        // Active is index 1, close it, should fall back to index 0
        final String firstTabId = cubit.state.tabs[1].id;
        cubit.closeTab(firstTabId);

        expect(cubit.state.tabs.length, 1);
        expect(cubit.state.activeTabIndex, 0);
      });

      test('does nothing when tab id not found', () {
        cubit.addTab('/first');

        cubit.closeTab('nonexistent');

        expect(cubit.state.tabs.length, 2);
      });
    });

    group('updateTabDisplayName', () {
      test('updates name of specified tab', () {
        cubit.addTab('/images');

        final String tabId = cubit.state.tabs[1].id;
        cubit.updateTabDisplayName(tabId, 'My Photos');

        expect(cubit.state.tabs[1].displayName, 'My Photos');
      });

      test('does not affect other tabs', () {
        cubit.addTab('/images');

        final String tabId = cubit.state.tabs[1].id;
        cubit.updateTabDisplayName(tabId, 'My Photos');

        expect(cubit.state.tabs[0].displayName, 'New Tab');
      });
    });

    group('updateTabFolderPath', () {
      test('updates folder path and display name', () {
        cubit.addTab('/old');

        final String tabId = cubit.state.tabs[1].id;
        cubit.updateTabFolderPath(tabId, '/new/photos');

        expect(cubit.state.tabs[1].folderPath, '/new/photos');
        expect(cubit.state.tabs[1].displayName, 'photos');
      });
    });

    group('findTabByFolderPath', () {
      test('returns matching tab', () {
        cubit.addTab('/path/to/images');

        final AppTab? result = cubit.findTabByFolderPath('/path/to/images');

        expect(result, isNotNull);
        expect(result!.folderPath, '/path/to/images');
      });

      test('returns null when not found', () {
        cubit.addTab('/path/to/images');

        final AppTab? result = cubit.findTabByFolderPath('/nonexistent');

        expect(result, isNull);
      });
    });

    group('activateOrAddTab', () {
      test('activates existing tab', () {
        cubit.addTab('/images');
        cubit.switchTab(0);

        expect(cubit.state.activeTabIndex, 0);

        cubit.activateOrAddTab('/images');

        expect(cubit.state.activeTabIndex, 1);
        expect(cubit.state.tabs.length, 2);
      });

      test('creates new tab when folder not open', () {
        cubit.activateOrAddTab('/new/folder');

        expect(cubit.state.tabs.length, 2);
        expect(cubit.state.activeTabIndex, 1);
        expect(cubit.state.activeTab.folderPath, '/new/folder');
      });
    });

    group('activeTabId', () {
      test('returns id of active tab', () {
        expect(cubit.activeTabId, 'default');
      });
    });
  });
}

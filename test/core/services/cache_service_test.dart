import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/services/cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const CacheService cacheService = CacheService();

  group('CacheService multi-tab', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('saveTabPaths / loadTabPaths', () {
      test('saves and loads empty list', () async {
        await cacheService.saveTabPaths(<String>[]);
        final List<String> result = await cacheService.loadTabPaths();
        expect(result, isEmpty);
      });

      test('saves and loads folder paths', () async {
        await cacheService.saveTabPaths(<String>['/photos', '/images']);
        final List<String> result = await cacheService.loadTabPaths();
        expect(result, <String>['/photos', '/images']);
      });

      test('loadTabPaths returns empty list when nothing saved', () async {
        final List<String> result = await cacheService.loadTabPaths();
        expect(result, isEmpty);
      });
    });

    group('saveActiveTabIndex / loadActiveTabIndex', () {
      test('saves and loads active tab index', () async {
        await cacheService.saveActiveTabIndex(3);
        final int result = await cacheService.loadActiveTabIndex();
        expect(result, 3);
      });

      test('loadActiveTabIndex returns 0 when nothing saved', () async {
        final int result = await cacheService.loadActiveTabIndex();
        expect(result, 0);
      });
    });

    group('backward compatibility', () {
      test('saveFolderPath still works', () async {
        await cacheService.saveFolderPath('/legacy');
        final String? result = await cacheService.loadFolderPath();
        expect(result, '/legacy');
      });

      test('clearFolderPath removes the saved path', () async {
        await cacheService.saveFolderPath('/legacy');
        await cacheService.clearFolderPath();
        expect(await cacheService.loadFolderPath(), isNull);
      });

      test('loadFolderPath returns null when nothing saved', () async {
        expect(await cacheService.loadFolderPath(), isNull);
      });
    });

    group('macOS bookmarks', () {
      test('saves and loads a bookmark for a folder path', () async {
        await cacheService.saveMacosBookmark(
          bookmark: 'bm-data',
          folderPath: '/photos',
        );
        final String? result = await cacheService.loadMacosBookmark(
          folderPath: '/photos',
        );
        expect(result, 'bm-data');
      });

      test('returns null when no bookmark stored for the path', () async {
        final String? result = await cacheService.loadMacosBookmark(
          folderPath: '/nope',
        );
        expect(result, isNull);
      });

      test('clearMacosBookmark removes the stored bookmark', () async {
        await cacheService.saveMacosBookmark(
          bookmark: 'bm',
          folderPath: '/photos',
        );
        await cacheService.clearMacosBookmark(folderPath: '/photos');
        expect(
          await cacheService.loadMacosBookmark(folderPath: '/photos'),
          isNull,
        );
      });

      test('bookmark keys are isolated per folder path', () async {
        await cacheService.saveMacosBookmark(bookmark: 'a', folderPath: '/a');
        await cacheService.saveMacosBookmark(bookmark: 'b', folderPath: '/b');
        expect(await cacheService.loadMacosBookmark(folderPath: '/a'), 'a');
        expect(await cacheService.loadMacosBookmark(folderPath: '/b'), 'b');
      });
    });
  });
}

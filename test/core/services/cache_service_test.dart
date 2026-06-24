import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/services/cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheService multi-tab', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('saveTabPaths / loadTabPaths', () {
      test('saves and loads empty list', () async {
        await CacheService.saveTabPaths(<String>[]);
        final List<String> result = await CacheService.loadTabPaths();
        expect(result, isEmpty);
      });

      test('saves and loads folder paths', () async {
        await CacheService.saveTabPaths(<String>['/photos', '/images']);
        final List<String> result = await CacheService.loadTabPaths();
        expect(result, <String>['/photos', '/images']);
      });

      test('loadTabPaths returns empty list when nothing saved', () async {
        final List<String> result = await CacheService.loadTabPaths();
        expect(result, isEmpty);
      });
    });

    group('saveActiveTabIndex / loadActiveTabIndex', () {
      test('saves and loads active tab index', () async {
        await CacheService.saveActiveTabIndex(3);
        final int result = await CacheService.loadActiveTabIndex();
        expect(result, 3);
      });

      test('loadActiveTabIndex returns 0 when nothing saved', () async {
        final int result = await CacheService.loadActiveTabIndex();
        expect(result, 0);
      });
    });

    group('backward compatibility', () {
      test('saveFolderPath still works', () async {
        await CacheService.saveFolderPath('/legacy');
        final String? result = await CacheService.loadFolderPath();
        expect(result, '/legacy');
      });

      test('clearFolderPath removes the saved path', () async {
        await CacheService.saveFolderPath('/legacy');
        await CacheService.clearFolderPath();
        expect(await CacheService.loadFolderPath(), isNull);
      });

      test('loadFolderPath returns null when nothing saved', () async {
        expect(await CacheService.loadFolderPath(), isNull);
      });
    });

    group('macOS bookmarks', () {
      test('saves and loads a bookmark for a folder path', () async {
        await CacheService.saveMacosBookmark(
          bookmark: 'bm-data',
          folderPath: '/photos',
        );
        final String? result = await CacheService.loadMacosBookmark(
          folderPath: '/photos',
        );
        expect(result, 'bm-data');
      });

      test('returns null when no bookmark stored for the path', () async {
        final String? result = await CacheService.loadMacosBookmark(
          folderPath: '/nope',
        );
        expect(result, isNull);
      });

      test('clearMacosBookmark removes the stored bookmark', () async {
        await CacheService.saveMacosBookmark(
          bookmark: 'bm',
          folderPath: '/photos',
        );
        await CacheService.clearMacosBookmark(folderPath: '/photos');
        expect(
          await CacheService.loadMacosBookmark(folderPath: '/photos'),
          isNull,
        );
      });

      test('bookmark keys are isolated per folder path', () async {
        await CacheService.saveMacosBookmark(bookmark: 'a', folderPath: '/a');
        await CacheService.saveMacosBookmark(bookmark: 'b', folderPath: '/b');
        expect(await CacheService.loadMacosBookmark(folderPath: '/a'), 'a');
        expect(await CacheService.loadMacosBookmark(folderPath: '/b'), 'b');
      });
    });
  });
}

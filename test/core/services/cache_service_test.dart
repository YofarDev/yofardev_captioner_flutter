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
    });
  });
}

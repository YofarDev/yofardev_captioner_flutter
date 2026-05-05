import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _folderPathKey = 'folderPath';

  static Future<void> saveFolderPath(String path) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderPathKey, path);
  }

  static Future<String?> loadFolderPath() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderPathKey);
  }

  static Future<void> clearFolderPath() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_folderPathKey);
  }

  static Future<void> saveMacosBookmark({
    required String bookmark,
    required String folderPath,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(folderPath, bookmark);
  }

  static Future<String?> loadMacosBookmark({required String folderPath}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(folderPath);
  }

  static Future<void> clearMacosBookmark({required String folderPath}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(folderPath);
  }

  static const String _tabPathsKey = 'tabPaths';
  static const String _activeTabIndexKey = 'activeTabIndex';

  static Future<void> saveTabPaths(List<String> paths) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tabPathsKey, paths);
  }

  static Future<List<String>> loadTabPaths() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_tabPathsKey) ?? <String>[];
  }

  static Future<void> saveActiveTabIndex(int index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeTabIndexKey, index);
  }

  static Future<int> loadActiveTabIndex() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeTabIndexKey) ?? 0;
  }
}

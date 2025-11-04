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
}

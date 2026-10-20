import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  const CacheService();

  static const String _folderPathKey = 'folderPath';

  static const String _maxImageDimensionKey = 'maxImageDimension';
  static const int defaultMaxImageDimension = 512;

  Future<void> saveMaxImageDimension(int dimension) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxImageDimensionKey, dimension);
  }

  Future<int> loadMaxImageDimension() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxImageDimensionKey) ?? defaultMaxImageDimension;
  }

  Future<void> saveFolderPath(String path) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderPathKey, path);
  }

  Future<String?> loadFolderPath() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderPathKey);
  }

  Future<void> clearFolderPath() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_folderPathKey);
  }

  Future<void> saveMacosBookmark({
    required String bookmark,
    required String folderPath,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(folderPath, bookmark);
  }

  Future<String?> loadMacosBookmark({required String folderPath}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(folderPath);
  }

  Future<void> clearMacosBookmark({required String folderPath}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(folderPath);
  }

  static const String _tabPathsKey = 'tabPaths';
  static const String _activeTabIndexKey = 'activeTabIndex';

  Future<void> saveTabPaths(List<String> paths) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tabPathsKey, paths);
  }

  Future<List<String>> loadTabPaths() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_tabPathsKey) ?? <String>[];
  }

  Future<void> saveActiveTabIndex(int index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeTabIndexKey, index);
  }

  Future<int> loadActiveTabIndex() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeTabIndexKey) ?? 0;
  }

  static const String _convertPromptKey = 'convertPrompt';

  Future<void> saveConvertPrompt(String prompt) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_convertPromptKey, prompt);
  }

  Future<String?> loadConvertPrompt() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_convertPromptKey);
  }

  static const String _agentApiEnabledKey = 'agentApiEnabled';
  static const String _agentApiPortKey = 'agentApiPort';
  static const String _agentApiTokenKey = 'agentApiToken';
  static const int defaultAgentApiPort = 8765;

  Future<void> saveAgentApiEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_agentApiEnabledKey, enabled);
  }

  Future<bool> loadAgentApiEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_agentApiEnabledKey) ?? true;
  }

  Future<void> saveAgentApiPort(int port) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_agentApiPortKey, port);
  }

  Future<int> loadAgentApiPort() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_agentApiPortKey) ?? defaultAgentApiPort;
  }

  Future<void> saveAgentApiToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_agentApiTokenKey, token);
  }

  Future<String?> loadAgentApiToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_agentApiTokenKey);
  }
}

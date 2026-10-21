import 'dart:io';

import 'package:logging/logging.dart';

class FolderUtils {
  static final Logger _logger = Logger('FolderUtils');

  /// Opens the folder at the given [folderPath] using the operating system's default application.
  ///
  /// Supports macOS, Windows, and Linux.
  static void openFolderWithDefaultApp(String folderPath) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', <String>[folderPath]);
      } else if (Platform.isWindows) {
        await Process.run('start', <String>[folderPath], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', <String>[folderPath]);
      }
    } catch (e) {
      _logger.warning('Error opening image: $e');
    }
  }
}

import 'dart:io';

class BashScriptsRunnner {
  static Future<Process> run(String scriptContent, List<String> arguments) {
    return Process.start('bash', <String>[
      '-c',
      scriptContent,
      '--',
      ...arguments,
    ]);
  }
}

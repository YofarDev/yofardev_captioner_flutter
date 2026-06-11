import 'dart:io';

/// Abstraction over [Process.run] for testability.
class ProcessRunner {
  const ProcessRunner();

  Future<ProcessResult> run(String executable, List<String> arguments) =>
      Process.run(executable, arguments);
}

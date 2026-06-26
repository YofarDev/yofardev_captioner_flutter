import 'dart:async';
import 'dart:io';

import '../../../../core/utils/cancel_token.dart';

/// Abstraction over process spawning for testability.
class ProcessRunner {
  const ProcessRunner();

  /// Runs [executable] with [arguments] and returns its result.
  ///
  /// When [cancelToken] is provided, the process is started (not just `run`)
  /// so it can be killed mid-flight: if cancellation is requested while the
  /// process is still running, it is sent [ProcessSignal.sigkill] and a
  /// [CancellationException] is thrown. This frees resources (e.g. local VRAM
  /// held by a vision model) immediately instead of waiting for completion.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken == null) {
      return Process.run(executable, arguments);
    }

    final Process process = await Process.start(executable, arguments);

    // Collect output for the result, mirroring Process.run's defaults.
    final Future<String> stdoutFuture = process.stdout
        .transform<String>(systemEncoding.decoder)
        .join();
    final Future<String> stderrFuture = process.stderr
        .transform<String>(systemEncoding.decoder)
        .join();

    final Future<int> exit = process.exitCode;

    // Race the process exit against cancellation.
    await Future.any<dynamic>(<Future<dynamic>>[exit, cancelToken.onCancel]);

    if (cancelToken.isCancelled) {
      process.kill(ProcessSignal.sigkill);
      // Reap the killed process so it doesn't linger as a zombie.
      await exit;
      throw const CancellationException();
    }

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      exit,
      stdoutFuture,
      stderrFuture,
    ]);
    return ProcessResult(
      process.pid,
      results[0] as int,
      results[1],
      results[2],
    );
  }
}

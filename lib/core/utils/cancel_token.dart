import 'dart:async';

/// A cooperative cancellation signal.
///
/// Threaded from an orchestrator (e.g. a Cubit) down to a long-running
/// operation so it can abort promptly — notably killing a local subprocess
/// that holds VRAM — instead of waiting for it to finish.
class CancelToken {
  final Completer<void> _completer = Completer<void>();

  /// True once [cancel] has been requested.
  bool get isCancelled => _completer.isCompleted;

  /// A future that completes when [cancel] is called. Use it to race against
  /// long-running work (e.g. via `Future.any`).
  Future<void> get onCancel => _completer.future;

  /// Requests cancellation. Idempotent: safe to call multiple times.
  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

/// Thrown by operations that were aborted via a [CancelToken]. Callers should
/// catch it separately from other failures so a cancelled item is not flagged
/// as a captioning error.
class CancellationException implements Exception {
  const CancellationException([this.message]);

  final String? message;

  @override
  String toString() => message == null
      ? 'CancellationException'
      : 'CancellationException: $message';
}

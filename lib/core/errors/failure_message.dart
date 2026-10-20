import 'failure.dart';

/// English user-facing message for each [Failure] variant. Deliberate
/// deviation from the FlutterForge skill: no l10n today; if the app
/// localizes later this becomes `localizeFailure(context, failure)`.
String failureMessage(Failure f) {
  return switch (f) {
    FailureServer() =>
      'The server encountered an error. Please try again later.',
    FailureNetwork() =>
      'A network problem occurred. Check your connection and try again.',
    FailureUnauthorized() =>
      'You are not authorized. Check your credentials and try again.',
    FailureNotFound() => 'The requested item could not be found.',
    FailureInvalidData() => 'The data received was invalid or corrupted.',
    FailureIo() => 'A file could not be read or written.',
    FailureUnexpected() => 'Something went wrong. Please try again.',
  };
}

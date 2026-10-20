import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'failure.dart';

/// Maps a caught exception to a typed [Failure], logging the diagnostic
/// detail (tag, exception, stack trace) exactly once — at this boundary.
/// Callers only see the typed result.
Failure mapExceptionToFailure(
  Object e, {
  StackTrace? stackTrace,
  String tag = 'error',
}) {
  final String st = stackTrace?.toString() ?? StackTrace.current.toString();
  final Logger logger = GetIt.I<Logger>();
  logger.severe('$tag: $e\n$st');

  if (e is TimeoutException || e is SocketException || e is HttpException) {
    return Failure.network(message: e.toString());
  }
  if (e is FileSystemException) {
    return Failure.io(message: e.toString());
  }
  if (e is FormatException || e is TypeError) {
    return Failure.invalidData(message: e.toString());
  }
  return Failure.unexpected(message: e.toString());
}

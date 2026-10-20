import 'package:equatable/equatable.dart';

/// Sealed failure hierarchy used as the `Left` side of `Either<Failure, T>`
/// at repository boundaries. `message` is diagnostic only — never shown to
/// users (see `failureMessage` for user-facing text).
sealed class Failure extends Equatable {
  const Failure({this.message});

  final String? message;

  const factory Failure.serverError({String? message}) = FailureServer;
  const factory Failure.network({String? message}) = FailureNetwork;
  const factory Failure.unauthorized({String? message}) = FailureUnauthorized;
  const factory Failure.notFound({String? message}) = FailureNotFound;
  const factory Failure.invalidData({String? message}) = FailureInvalidData;
  const factory Failure.io({String? message}) = FailureIo;
  const factory Failure.unexpected({String? message}) = FailureUnexpected;

  @override
  List<Object?> get props => <Object?>[message];
}

class FailureServer extends Failure {
  const FailureServer({super.message});
}

class FailureNetwork extends Failure {
  const FailureNetwork({super.message});
}

class FailureUnauthorized extends Failure {
  const FailureUnauthorized({super.message});
}

class FailureNotFound extends Failure {
  const FailureNotFound({super.message});
}

class FailureInvalidData extends Failure {
  const FailureInvalidData({super.message});
}

class FailureIo extends Failure {
  const FailureIo({super.message});
}

class FailureUnexpected extends Failure {
  const FailureUnexpected({super.message});
}

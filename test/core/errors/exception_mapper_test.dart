import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/exception_mapper.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';

class _MockLogger extends Mock implements Logger {}

void main() {
  late _MockLogger mockLogger;

  setUp(() {
    mockLogger = _MockLogger();
    if (locator.isRegistered<Logger>()) {
      locator.unregister<Logger>();
    }
    locator.registerLazySingleton<Logger>(() => mockLogger);
  });

  tearDown(() {
    locator.unregister<Logger>();
  });

  group('mapExceptionToFailure', () {
    test('maps TimeoutException to network', () {
      final Failure failure = mapExceptionToFailure(
        TimeoutException('timed out'),
        tag: 'test',
      );
      expect(failure, isA<FailureNetwork>());
    });

    test('maps SocketException to network', () {
      final Failure failure = mapExceptionToFailure(
        const SocketException('closed'),
        tag: 'test',
      );
      expect(failure, isA<FailureNetwork>());
    });

    test('maps HttpException to network', () {
      final Failure failure = mapExceptionToFailure(
        const HttpException('bad status'),
        tag: 'test',
      );
      expect(failure, isA<FailureNetwork>());
    });

    test('maps FileSystemException to io', () {
      final Failure failure = mapExceptionToFailure(
        const FileSystemException('no file', '/tmp/x'),
        tag: 'test',
      );
      expect(failure, isA<FailureIo>());
    });

    test('maps FormatException to invalidData', () {
      final Failure failure = mapExceptionToFailure(
        const FormatException('bad json'),
        tag: 'test',
      );
      expect(failure, isA<FailureInvalidData>());
    });

    test('maps TypeError to invalidData', () {
      final Failure failure = mapExceptionToFailure(TypeError(), tag: 'test');
      expect(failure, isA<FailureInvalidData>());
    });

    test('maps unknown exceptions to unexpected', () {
      final Failure failure = mapExceptionToFailure(
        StateError('boom'),
        tag: 'test',
      );
      expect(failure, isA<FailureUnexpected>());
    });

    test('logs exactly once with tag and stack trace', () {
      final StackTrace stackTrace = StackTrace.current;
      mapExceptionToFailure(
        StateError('boom'),
        stackTrace: stackTrace,
        tag: 'MyRepo',
      );

      verify(
        mockLogger.severe(argThat(contains('MyRepo: Bad state: boom'))),
      ).called(1);
      verifyNoMoreInteractions(mockLogger);
    });

    test('uses provided exception message in Failure', () {
      final Failure failure = mapExceptionToFailure(
        const SocketException('conn refused'),
        tag: 'test',
      );
      expect(failure.message, contains('conn refused'));
    });
  });
}

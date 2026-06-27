import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/utils/cancel_token.dart';

void main() {
  group('CancelToken', () {
    test('is not cancelled initially', () {
      final CancelToken token = CancelToken();
      expect(token.isCancelled, isFalse);
    });

    test('cancel() marks the token as cancelled', () {
      final CancelToken token = CancelToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() is idempotent and never throws on repeat calls', () {
      final CancelToken token = CancelToken();
      token.cancel();
      token.cancel();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('onCancel completes when cancel() is called afterwards', () async {
      final CancelToken token = CancelToken();
      bool completed = false;
      token.onCancel.then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      token.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(completed, isTrue);
    });

    test('onCancel completes immediately when already cancelled', () async {
      final CancelToken token = CancelToken();
      token.cancel();
      // A late subscriber should not hang.
      await expectLater(token.onCancel, completes);
    });
  });

  group('CancellationException', () {
    test('is an Exception', () {
      expect(const CancellationException(), isA<Exception>());
    });

    test('toString uses default text when no message is given', () {
      expect(const CancellationException().toString(), 'CancellationException');
    });

    test('toString includes the message when one is provided', () {
      expect(
        const CancellationException('aborted by user').toString(),
        'CancellationException: aborted by user',
      );
    });
  });
}

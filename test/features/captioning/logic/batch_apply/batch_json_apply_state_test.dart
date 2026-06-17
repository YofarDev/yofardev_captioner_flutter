import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/logic/batch_apply/batch_json_apply_state.dart';

void main() {
  group('BatchJsonApplyState', () {
    test('BatchJsonApplyInitial props and equality', () {
      expect(const BatchJsonApplyInitial().props, <Object?>[]);
      expect(
        const BatchJsonApplyInitial(),
        equals(const BatchJsonApplyInitial()),
      );
    });

    test('BatchJsonApplyInProgress props and equality', () {
      const BatchJsonApplyInProgress state = BatchJsonApplyInProgress(
        processedImages: 2,
        totalImages: 10,
        currentImageName: 'test.jpg',
      );
      expect(state.processedImages, 2);
      expect(state.totalImages, 10);
      expect(state.currentImageName, 'test.jpg');
      expect(state.props, <Object?>[2, 10, 'test.jpg']);
      expect(
        state,
        equals(const BatchJsonApplyInProgress(
          processedImages: 2,
          totalImages: 10,
          currentImageName: 'test.jpg',
        )),
      );
    });

    test('BatchJsonApplyInProgress null currentImageName', () {
      const BatchJsonApplyInProgress state = BatchJsonApplyInProgress(
        processedImages: 0,
        totalImages: 5,
      );
      expect(state.currentImageName, isNull);
      expect(state.props, <Object?>[0, 5, null]);
    });

    test('BatchJsonApplyCompleted props and equality', () {
      expect(const BatchJsonApplyCompleted().props, <Object?>[]);
      expect(
        const BatchJsonApplyCompleted(),
        equals(const BatchJsonApplyCompleted()),
      );
    });

    test('BatchJsonApplyError props and equality', () {
      const BatchJsonApplyError state = BatchJsonApplyError(message: 'error');
      expect(state.message, 'error');
      expect(state.props, <Object?>['error']);
      expect(
        state,
        equals(const BatchJsonApplyError(message: 'error')),
      );
    });

    test('inequality between different states', () {
      expect(
        const BatchJsonApplyInitial(),
        isNot(equals(const BatchJsonApplyCompleted())),
      );
      expect(
        const BatchJsonApplyInProgress(processedImages: 1, totalImages: 5),
        isNot(equals(const BatchJsonApplyInProgress(
          processedImages: 2,
          totalImages: 5,
        ))),
      );
    });
  });
}

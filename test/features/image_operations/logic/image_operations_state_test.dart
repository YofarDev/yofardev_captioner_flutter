import 'package:flutter_test/flutter_test.dart';

import 'package:yofardev_captioner/features/image_operations/logic/image_operations_cubit.dart';

void main() {
  group('ImageOperationsState', () {
    test('has correct default values', () {
      const ImageOperationsState state = ImageOperationsState();

      expect(state.status, ImageOperationsStatus.initial);
      expect(state.progress, 0.0);
      expect(state.error, isNull);
    });

    test('copyWith preserves values when no arguments given', () {
      const ImageOperationsState original = ImageOperationsState(
        status: ImageOperationsStatus.inProgress,
        progress: 0.5,
        error: 'some error',
      );

      final ImageOperationsState copy = original.copyWith();

      expect(copy.status, original.status);
      expect(copy.progress, original.progress);
      expect(copy.error, original.error);
    });

    test('copyWith updates individual fields', () {
      const ImageOperationsState original = ImageOperationsState();

      final ImageOperationsState withStatus = original.copyWith(
        status: ImageOperationsStatus.success,
      );
      expect(withStatus.status, ImageOperationsStatus.success);
      expect(withStatus.progress, 0.0);
      expect(withStatus.error, isNull);

      final ImageOperationsState withProgress = original.copyWith(
        progress: 0.75,
      );
      expect(withProgress.progress, 0.75);

      final ImageOperationsState withError = original.copyWith(error: 'failed');
      expect(withError.error, 'failed');
    });

    test('props contains all fields for equality', () {
      const ImageOperationsState state = ImageOperationsState(
        status: ImageOperationsStatus.failure,
        progress: 1.0,
        error: 'err',
      );

      expect(state.props.length, 3);
      expect(state.props, <Object?>[ImageOperationsStatus.failure, 1.0, 'err']);
    });

    test('value equality works via Equatable', () {
      const ImageOperationsState a = ImageOperationsState(
        status: ImageOperationsStatus.inProgress,
        progress: 0.3,
      );
      const ImageOperationsState b = ImageOperationsState(
        status: ImageOperationsStatus.inProgress,
        progress: 0.3,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ImageOperationsStatus', () {
    test('has all expected values', () {
      expect(ImageOperationsStatus.values.length, 4);
      expect(
        ImageOperationsStatus.values,
        contains(ImageOperationsStatus.initial),
      );
      expect(
        ImageOperationsStatus.values,
        contains(ImageOperationsStatus.inProgress),
      );
      expect(
        ImageOperationsStatus.values,
        contains(ImageOperationsStatus.success),
      );
      expect(
        ImageOperationsStatus.values,
        contains(ImageOperationsStatus.failure),
      );
    });
  });
}

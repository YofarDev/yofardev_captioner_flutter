part of 'image_operations_cubit.dart';

enum ImageOperationsStatus { initial, inProgress, success, failure }

class ImageOperationsState extends Equatable {
  final ImageOperationsStatus status;
  final double progress;
  final String? error;

  const ImageOperationsState({
    this.status = ImageOperationsStatus.initial,
    this.progress = 0.0,
    this.error,
  });

  ImageOperationsState copyWith({
    ImageOperationsStatus? status,
    double? progress,
    String? error,
  }) {
    return ImageOperationsState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, progress, error];
}

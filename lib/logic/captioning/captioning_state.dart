part of 'captioning_cubit.dart';

enum CaptioningStatus { initial, inProgress, success, failure }

class CaptioningState extends Equatable {
  final CaptioningStatus status;
  final double progress;
  final int processedImages;
  final int totalImages;
  final String? error;

  const CaptioningState({
    this.status = CaptioningStatus.initial,
    this.progress = 0.0,
    this.processedImages = 0,
    this.totalImages = 0,
    this.error,
  });

  CaptioningState copyWith({
    CaptioningStatus? status,
    double? progress,
    int? processedImages,
    int? totalImages,
    String? error,
  }) {
    return CaptioningState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      processedImages: processedImages ?? this.processedImages,
      totalImages: totalImages ?? this.totalImages,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        progress,
        processedImages,
        totalImages,
        error,
      ];
}

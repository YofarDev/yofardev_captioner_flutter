part of 'captioning_cubit.dart';

enum CaptioningStatus { initial, inProgress, success, failure }

class CaptioningState extends Equatable {
  final CaptioningStatus status;
  final double progress;
  final String? error;

  const CaptioningState({
    this.status = CaptioningStatus.initial,
    this.progress = 0.0,
    this.error,
  });

  CaptioningState copyWith({
    CaptioningStatus? status,
    double? progress,
    String? error,
  }) {
    return CaptioningState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, progress, error];
}

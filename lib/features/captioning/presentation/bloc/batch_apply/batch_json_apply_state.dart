import 'package:equatable/equatable.dart';

sealed class BatchJsonApplyState extends Equatable {
  const BatchJsonApplyState();

  @override
  List<Object?> get props => <Object?>[];
}

class BatchJsonApplyInitial extends BatchJsonApplyState {
  const BatchJsonApplyInitial();
}

class BatchJsonApplyInProgress extends BatchJsonApplyState {
  final int processedImages;
  final int totalImages;
  final String? currentImageName;

  const BatchJsonApplyInProgress({
    required this.processedImages,
    required this.totalImages,
    this.currentImageName,
  });

  @override
  List<Object?> get props => <Object?>[
    processedImages,
    totalImages,
    currentImageName,
  ];
}

class BatchJsonApplyCompleted extends BatchJsonApplyState {
  const BatchJsonApplyCompleted();
}

class BatchJsonApplyError extends BatchJsonApplyState {
  final String message;

  const BatchJsonApplyError({required this.message});

  @override
  List<Object?> get props => <Object?>[message];
}

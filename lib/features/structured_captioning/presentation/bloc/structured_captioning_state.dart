part of 'structured_captioning_cubit.dart';

enum StructuredCaptioningStatus { initial, inProgress, success, failure }

enum StructuredCaptionStep {
  idle,
  extractingPalette,
  vlmAnalysis,
  samDetection,
  elementPalettes,
  buildingCaption,
}

class StructuredCaptioningState extends Equatable {
  const StructuredCaptioningState({
    this.status = StructuredCaptioningStatus.initial,
    this.currentStep = StructuredCaptionStep.idle,
    this.progress = 0.0,
    this.processedImages = 0,
    this.totalImages = 0,
    this.currentlyProcessingImage,
    this.error,
    this.isCancelling = false,
    this.stepLabel,
  });

  final StructuredCaptioningStatus status;
  final StructuredCaptionStep currentStep;
  final double progress;
  final int processedImages;
  final int totalImages;
  final String? currentlyProcessingImage;
  final String? error;
  final bool isCancelling;

  /// Human-readable label for the current sub-step.
  final String? stepLabel;

  StructuredCaptioningState copyWith({
    StructuredCaptioningStatus? status,
    StructuredCaptionStep? currentStep,
    double? progress,
    int? processedImages,
    int? totalImages,
    String? currentlyProcessingImage,
    bool setCurrentlyProcessingImage = false,
    String? error,
    bool clearError = false,
    bool? isCancelling,
    String? stepLabel,
    bool clearStepLabel = false,
  }) {
    return StructuredCaptioningState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      progress: progress ?? this.progress,
      processedImages: processedImages ?? this.processedImages,
      totalImages: totalImages ?? this.totalImages,
      currentlyProcessingImage: setCurrentlyProcessingImage
          ? currentlyProcessingImage
          : this.currentlyProcessingImage,
      error: clearError ? null : (error ?? this.error),
      isCancelling: isCancelling ?? this.isCancelling,
      stepLabel: clearStepLabel ? null : (stepLabel ?? this.stepLabel),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    currentStep,
    progress,
    processedImages,
    totalImages,
    currentlyProcessingImage,
    error,
    isCancelling,
    stepLabel,
  ];
}

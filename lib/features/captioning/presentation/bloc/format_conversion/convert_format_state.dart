import 'package:equatable/equatable.dart';

import '../../../../../core/models/moss_format.dart';

sealed class ConvertFormatState extends Equatable {
  const ConvertFormatState();

  @override
  List<Object?> get props => <Object?>[];
}

class ConvertFormatInitial extends ConvertFormatState {
  const ConvertFormatInitial();
}

class ConvertFormatInProgress extends ConvertFormatState {
  final int processedImages;
  final int totalImages;
  final String? currentImageName;
  final int converted;
  final int skipped;
  final int failed;

  /// Per-file warnings/losses accumulated so far.
  final List<MossFormatDiagnostic> diagnostics;

  const ConvertFormatInProgress({
    required this.processedImages,
    required this.totalImages,
    this.currentImageName,
    this.converted = 0,
    this.skipped = 0,
    this.failed = 0,
    this.diagnostics = const <MossFormatDiagnostic>[],
  });

  @override
  List<Object?> get props => <Object?>[
    processedImages,
    totalImages,
    currentImageName,
    converted,
    skipped,
    failed,
    diagnostics,
  ];
}

class ConvertFormatCompleted extends ConvertFormatState {
  final int converted;
  final int skipped;
  final int failed;

  /// True when the run was cancelled partway. Already-written captions are
  /// kept — cancellation never claims to undo successful writes.
  final bool cancelled;

  /// Human-readable failure (e.g. destination category could not be
  /// created) for runs that aborted before doing any work.
  final String? fatalError;

  final List<MossFormatDiagnostic> diagnostics;

  const ConvertFormatCompleted({
    required this.converted,
    this.skipped = 0,
    this.failed = 0,
    this.cancelled = false,
    this.fatalError,
    this.diagnostics = const <MossFormatDiagnostic>[],
  });

  @override
  List<Object?> get props => <Object?>[
    converted,
    skipped,
    failed,
    cancelled,
    fatalError,
    diagnostics,
  ];
}

/// Backwards-compatible error state: fatal problems surface as a completed
/// run with zero work done plus a message.
class ConvertFormatError extends ConvertFormatCompleted {
  // ignore: prefer_const_constructors_in_immutables
  ConvertFormatError({required String message})
    : super(converted: 0, failed: 0, fatalError: message);

  String get message => fatalError!;
}

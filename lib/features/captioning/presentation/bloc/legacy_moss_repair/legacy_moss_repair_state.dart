import 'package:equatable/equatable.dart';

import '../../../../../core/models/moss_format.dart';
import '../../../../../core/models/moss_repair.dart';

sealed class LegacyMossRepairState extends Equatable {
  const LegacyMossRepairState();

  @override
  List<Object?> get props => <Object?>[];
}

class LegacyMossRepairInitial extends LegacyMossRepairState {
  const LegacyMossRepairInitial();
}

/// One reviewable row of the repair preview. Captures everything the repair
/// will need (source category + exact texts) at audit time so Apply cannot
/// silently act on a different category or edited content.
class MossRepairCandidate extends Equatable {
  const MossRepairCandidate({
    required this.imageId,
    required this.fileName,
    required this.imagePath,
    required this.strategy,
    required this.draftWidth,
    required this.draftHeight,
    required this.actualWidth,
    required this.actualHeight,
    required this.itemCount,
    required this.mossText,
    required this.sourceCategory,
    required this.destinationCategory,
    this.mossEdited = false,
    this.ideogramSourceCategory,
    this.ideogramSourceText,
    this.detail = '',
    this.repairedPreview = const <List<int>?>[],
    this.reconvertPreview = const <List<int>?>[],
  });

  final String imageId;
  final String fileName;
  final String imagePath;
  final MossRepairStrategy strategy;
  final int draftWidth;
  final int draftHeight;
  final int actualWidth;
  final int actualHeight;
  final int itemCount;

  /// MOSS text captured at audit time; the write is refused if the live
  /// caption no longer matches.
  final String mossText;

  /// The MOSS category this audit ran against — Apply uses this, never the
  /// currently active category.
  final String sourceCategory;

  /// Destination category bound at audit time.
  final String destinationCategory;

  /// Whether the stored MOSS caption carries the edited flag. Informative
  /// only: initial conversions also set it, so it never decides the strategy
  /// by itself — reconversion additionally requires a discoverable Ideogram
  /// source, and the reviewer can override the strategy per row.
  final bool mossEdited;

  /// Ideogram source discovered at audit time (category + captured text).
  final String? ideogramSourceCategory;
  final String? ideogramSourceText;

  /// Human explanation for the chosen strategy.
  final String detail;

  /// Repaired box per surviving item (rescale path), aligned with the draft
  /// items — drives the review overlay and numeric table.
  final List<List<int>?> repairedPreview;

  /// Boxes the RECONVERSION strategy would produce (Ideogram source
  /// projected onto the real frame), aligned with the draft items where a
  /// box exists; null for items the reconversion drops.
  final List<List<int>?> reconvertPreview;

  @override
  List<Object?> get props => <Object?>[
    imageId,
    strategy,
    draftWidth,
    draftHeight,
    actualWidth,
    actualHeight,
    itemCount,
    mossText,
    sourceCategory,
    destinationCategory,
    mossEdited,
    ideogramSourceCategory,
    ideogramSourceText,
    repairedPreview,
    reconvertPreview,
  ];

  MossRepairCandidate copyWith({
    MossRepairStrategy? strategy,
    String? detail,
    List<List<int>?>? repairedPreview,
    List<List<int>?>? reconvertPreview,
  }) => MossRepairCandidate(
    imageId: imageId,
    fileName: fileName,
    imagePath: imagePath,
    strategy: strategy ?? this.strategy,
    draftWidth: draftWidth,
    draftHeight: draftHeight,
    actualWidth: actualWidth,
    actualHeight: actualHeight,
    itemCount: itemCount,
    mossText: mossText,
    sourceCategory: sourceCategory,
    destinationCategory: destinationCategory,
    mossEdited: mossEdited,
    ideogramSourceCategory: ideogramSourceCategory,
    ideogramSourceText: ideogramSourceText,
    detail: detail ?? this.detail,
    repairedPreview: repairedPreview ?? this.repairedPreview,
    reconvertPreview: reconvertPreview ?? this.reconvertPreview,
  );
}

class LegacyMossRepairPreview extends LegacyMossRepairState {
  const LegacyMossRepairPreview({
    required this.candidates,
    required this.diagnostics,
    required this.sourceCategory,
    required this.destinationCategory,
  });

  final List<MossRepairCandidate> candidates;

  /// Categories bound at audit time — Apply reuses exactly these.
  final String sourceCategory;
  final String destinationCategory;

  final List<MossFormatDiagnostic> diagnostics;

  int get repairable => candidates
      .where(
        (MossRepairCandidate c) =>
            c.strategy != MossRepairStrategy.skip &&
            c.strategy != MossRepairStrategy.none,
      )
      .length;

  @override
  List<Object?> get props => <Object?>[
    candidates,
    diagnostics,
    sourceCategory,
    destinationCategory,
  ];

  LegacyMossRepairPreview withCandidate(int index, MossRepairCandidate c) =>
      LegacyMossRepairPreview(
        candidates: <MossRepairCandidate>[
          ...candidates.sublist(0, index),
          c,
          ...candidates.sublist(index + 1),
        ],
        diagnostics: diagnostics,
        sourceCategory: sourceCategory,
        destinationCategory: destinationCategory,
      );
}

class LegacyMossRepairInProgress extends LegacyMossRepairState {
  final int processed;
  final int total;
  final int repaired;
  final int skipped;
  final int failed;

  const LegacyMossRepairInProgress({
    required this.processed,
    required this.total,
    required this.repaired,
    required this.skipped,
    this.failed = 0,
  });

  @override
  List<Object?> get props => <Object?>[
    processed,
    total,
    repaired,
    skipped,
    failed,
  ];
}

class LegacyMossRepairCompleted extends LegacyMossRepairState {
  final int repaired;
  final int skipped;
  final int failed;
  final bool cancelled;
  final String? fatalError;
  final List<MossFormatDiagnostic> diagnostics;

  const LegacyMossRepairCompleted({
    required this.repaired,
    required this.skipped,
    this.failed = 0,
    this.cancelled = false,
    this.fatalError,
    this.diagnostics = const <MossFormatDiagnostic>[],
  });

  @override
  List<Object?> get props => <Object?>[
    repaired,
    skipped,
    failed,
    cancelled,
    fatalError,
    diagnostics,
  ];
}

import 'package:equatable/equatable.dart';

import 'moss_bucketing.dart';

/// Versioned trainer preparation profile. v1 mirrors the pinned AI Toolkit
/// non-square-crop loader path: `aiToolkitBucket` selection, uniform max-axis
/// scale (ceil), central crop.
///
/// `divisibility` must match the trainer dataset config's `bucket_tolerance`
/// for the fixed-point property to hold (prepared dimensions fed back to the
/// loader produce scale 1 and crop offset 0). The MOSS canvas contract needs
/// 16; the AI Toolkit default is 64 — the manifest records both so the
/// mismatch is visible in the trainer config.
const String kMossTrainingProfileVersion = 'aitk-central-crop-v1';

/// Options for a MOSS training dataset export.
class MossTrainingExportOptions extends Equatable {
  const MossTrainingExportOptions({
    this.resolution = 1024,
    this.divisibility = 16,
    this.allowFrameReconciliation = false,
  });

  /// Resolution budget (bucket pixel target = resolution²).
  final int resolution;

  /// Bucket divisibility (trainer `bucket_tolerance`). MOSS canvases must be
  /// multiples of 16.
  final int divisibility;

  /// When false (default), a draft whose declared canvas disagrees with the
  /// real image in a non-legacy way is SKIPPED — imported layouts and changed
  /// images are not silently rescaled. When true (an explicit user choice in
  /// the dialog), mismatched drafts are rescaled to the real frame with the
  /// same documented assumption as the repair workflow.
  final bool allowFrameReconciliation;

  /// Returns diagnostics for out-of-range options (validated at the
  /// repository boundary).
  List<String> validationProblems() {
    final List<String> problems = <String>[];
    if (resolution < 16 || resolution > 4096) {
      problems.add('resolution must be between 16 and 4096, got $resolution');
    }
    if (divisibility < 1 || divisibility > 128) {
      problems.add('divisibility must be between 1 and 128, got $divisibility');
    }
    return problems;
  }

  @override
  List<Object?> get props => <Object?>[
    resolution,
    divisibility,
    allowFrameReconciliation,
  ];

  MossTrainingExportOptions copyWith({bool? allowFrameReconciliation}) =>
      MossTrainingExportOptions(
        resolution: resolution,
        divisibility: divisibility,
        allowFrameReconciliation:
            allowFrameReconciliation ?? this.allowFrameReconciliation,
      );
}

/// One transformed bounding box with its provenance.
class MossTrainingBox extends Equatable {
  const MossTrainingBox({
    required this.label,
    required this.caption,
    required this.sourceBox,
    required this.outputBox,
    this.text,
    this.tags = const <String>[],
    this.palette = const <String>[],
  });

  final String label;
  final String caption;

  /// Exact visible characters for `text` items.
  final String? text;

  /// Top-left `xyxy` pixels in the *source* frame.
  final List<int> sourceBox;

  /// Top-left `xyxy` pixels in the *output* (bucket) frame, rounded once.
  /// Null when the box collapsed to zero area.
  final List<int>? outputBox;

  final List<String> tags;
  final List<String> palette;

  @override
  List<Object?> get props => <Object?>[
    label,
    caption,
    text,
    sourceBox,
    outputBox,
    tags,
    palette,
  ];
}

/// Preparation plan for one image: source frame, bucket, realized resize,
/// crop offsets, and every box transformed through the identical geometry.
class MossTrainingPrepItem extends Equatable {
  const MossTrainingPrepItem({
    required this.imageId,
    required this.fileName,
    required this.sourcePath,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.transform,
    required this.boxes,
    required this.summaryCaption,
    required this.summaryMeta,
    required this.summaryPalette,
    this.droppedBoxCount = 0,
    this.warnings = const <String>[],
    this.outputExtension = 'png',
    this.summaryCanvas,
    required this.sourceLength,
    required this.sourceModified,
  });

  final String imageId;
  final String fileName;
  final String sourcePath;
  final int sourceWidth;
  final int sourceHeight;

  /// Source identity evidence captured at plan time (size + mtime). Verified
  /// at export time so a changed image at the same dimensions cannot be
  /// exported against a stale plan.
  final int sourceLength;
  final DateTime sourceModified;

  /// `summary.canvas` preserved from the draft into the prepared prompt.
  final String? summaryCanvas;
  final MossImageTransform transform;
  final List<MossTrainingBox> boxes;
  final String summaryCaption;
  final List<String> summaryMeta;
  final List<String> summaryPalette;
  final int droppedBoxCount;
  final List<String> warnings;

  /// Encoded output format for the prepared image (png, or jpg for jpeg
  /// sources).
  final String outputExtension;

  MossTrainingPrepItem copyWith({String? outputExtension}) =>
      MossTrainingPrepItem(
        imageId: imageId,
        fileName: fileName,
        sourcePath: sourcePath,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        transform: transform,
        boxes: boxes,
        summaryCaption: summaryCaption,
        summaryMeta: summaryMeta,
        summaryPalette: summaryPalette,
        droppedBoxCount: droppedBoxCount,
        warnings: warnings,
        outputExtension: outputExtension ?? this.outputExtension,
        summaryCanvas: summaryCanvas,
        sourceLength: sourceLength,
        sourceModified: sourceModified,
      );

  @override
  List<Object?> get props => <Object?>[
    imageId,
    fileName,
    sourceWidth,
    sourceHeight,
    transform,
    boxes,
    droppedBoxCount,
    warnings,
    outputExtension,
    summaryCanvas,
    sourceLength,
    sourceModified,
  ];
}

/// Images that cannot be prepared, with the reason.
class MossTrainingSkippedImage extends Equatable {
  const MossTrainingSkippedImage({
    required this.fileName,
    required this.reason,
  });

  final String fileName;
  final String reason;

  @override
  List<Object?> get props => <Object?>[fileName, reason];
}

/// One plan row plus its reviewer-controlled include choice. The exporter
/// only runs rows where [include] is true.
class MossTrainingPlanEntry extends Equatable {
  const MossTrainingPlanEntry({required this.item, this.include = true});

  final MossTrainingPrepItem item;
  final bool include;

  MossTrainingPlanEntry copyWith({bool? include}) =>
      MossTrainingPlanEntry(item: item, include: include ?? this.include);

  @override
  List<Object?> get props => <Object?>[item, include];
}

/// Reviewable plan: everything the exporter will do, before it does it.
class MossTrainingExportPlan extends Equatable {
  MossTrainingExportPlan({
    required this.options,
    required List<MossTrainingPrepItem> items,
    required this.skipped,
  }) : entries = <MossTrainingPlanEntry>[
         for (final MossTrainingPrepItem item in items)
           MossTrainingPlanEntry(item: item),
       ];

  const MossTrainingExportPlan.withEntries({
    required this.options,
    required this.entries,
    required this.skipped,
  });

  /// Reviewer-controlled rows (items mirrored for convenience).
  final List<MossTrainingPlanEntry> entries;

  /// All planned items, included or not.
  List<MossTrainingPrepItem> get items =>
      entries.map((MossTrainingPlanEntry e) => e.item).toList();

  final MossTrainingExportOptions options;
  final List<MossTrainingSkippedImage> skipped;

  /// `bucketWidth×bucketHeight → count` across INCLUDED rows.
  Map<String, int> get bucketSummary {
    final Map<String, int> buckets = <String, int>{};
    for (final MossTrainingPlanEntry e in entries) {
      if (!e.include) {
        continue;
      }
      final String key =
          '${e.item.transform.bucketWidth}x${e.item.transform.bucketHeight}';
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    return buckets;
  }

  /// Included rows only — what [IMossTrainingExportRepository.exportPlan]
  /// should process.
  List<MossTrainingPrepItem> get includedItems => entries
      .where((MossTrainingPlanEntry e) => e.include)
      .map((MossTrainingPlanEntry e) => e.item)
      .toList();

  int get includedCount =>
      entries.where((MossTrainingPlanEntry e) => e.include).length;

  MossTrainingExportPlan withEntry(int index, MossTrainingPlanEntry entry) =>
      MossTrainingExportPlan.withEntries(
        options: options,
        entries: <MossTrainingPlanEntry>[
          ...entries.sublist(0, index),
          entry,
          ...entries.sublist(index + 1),
        ],
        skipped: skipped,
      );

  @override
  List<Object?> get props => <Object?>[options, entries, skipped];
}

/// Summary of a completed export (the ZIP bytes are handed to the platform
/// save dialog by the cubit, not kept here).
class MossTrainingExportResult extends Equatable {
  const MossTrainingExportResult({
    required this.imageCount,
    required this.captionCount,
    required this.droppedBoxCount,
    required this.warnings,
    required this.outputHashes,
  });

  final int imageCount;
  final int captionCount;
  final int droppedBoxCount;
  final List<String> warnings;

  /// `prepared filename → sha256` of the encoded image bytes.
  final Map<String, String> outputHashes;

  @override
  List<Object?> get props => <Object?>[
    imageCount,
    captionCount,
    droppedBoxCount,
    warnings,
    outputHashes,
  ];
}

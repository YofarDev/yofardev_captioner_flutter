import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/models/app_image.dart';
import '../../domain/moss_training_models.dart';
import '../../domain/repositories/moss_training_export_repository.dart';

/// Drives the MOSS training export: build a reviewable plan, then produce
/// and hand the ZIP to the platform save dialog.
///
/// Lifecycle guarantees:
/// - [exportPlan] reports per-image progress and polls [cancel]; a cancelled
///   run never reaches the platform save dialog.
/// - Popping the dialog while work is in flight cancels the cubit (the widget
///   calls [cancel] on dispose); emissions stop at the next boundary.
/// - Reopening the dialog or changing options resets any stale plan
///   ([reset]) — the plan is only valid for the images/category/options it
///   was audited against, and the exporter additionally verifies source
///   identity (size + mtime) before each image.
class MossTrainingExportCubit extends Cubit<MossTrainingExportState> {
  MossTrainingExportCubit({required IMossTrainingExportRepository repository})
    : _repository = repository,
      super(const MossTrainingExportInitial());

  final IMossTrainingExportRepository _repository;
  bool _running = false;
  bool _cancelRequested = false;

  /// True while a plan/export is in flight — the owning widget cancels on
  /// dispose so no work (and no save dialog) survives a closed dialog.
  bool get isBusy => _running;

  /// Captures the images/category the current plan was built from, so stale
  /// plans can be detected when the source set changes — including CAPTION
  /// text changes in the live session (immutable snapshots cannot).
  String? _plannedCategory;
  List<AppImage>? _plannedImages;
  Map<String, String> _plannedCaptions = <String, String>{};

  Future<void> buildPlan({
    required List<AppImage> images,
    required String category,
    required MossTrainingExportOptions options,
  }) async {
    if (_running) {
      return;
    }
    _running = true;
    _cancelRequested = false;
    emit(const MossTrainingExportPlanning());
    final Either<Failure, MossTrainingExportPlan> result = await _repository
        .buildPlan(images: images, category: category, options: options);
    _running = false;
    if (isClosed) {
      return;
    }
    // A cancel that arrived DURING planning must not publish a plan.
    if (_cancelRequested) {
      emit(
        const MossTrainingExportDone(
          cancelled: true,
          saved: false,
          result: MossTrainingExportResult(
            imageCount: 0,
            captionCount: 0,
            droppedBoxCount: 0,
            warnings: <String>[],
            outputHashes: <String, String>{},
          ),
        ),
      );
      return;
    }
    result.fold(
      (Failure f) =>
          emit(MossTrainingExportError(message: f.message ?? 'plan failed')),
      (MossTrainingExportPlan plan) {
        _plannedCategory = category;
        _plannedImages = images;
        _plannedCaptions = <String, String>{
          for (final AppImage image in images)
            if (image.captions[category]?.text case final String text)
              image.id: text,
        };
        emit(MossTrainingExportPlanned(plan));
      },
    );
  }

  /// Reviewer include/skip choice for one planned row (Codex rev-2
  /// finding 4: crop review must be explicit per image).
  void setInclude(int index, bool include) {
    final MossTrainingExportState current = state;
    if (current is! MossTrainingExportPlanned || _running) {
      return;
    }
    if (index < 0 || index >= current.plan.entries.length) {
      return;
    }
    emit(
      MossTrainingExportPlanned(
        current.plan.withEntry(
          index,
          current.plan.entries[index].copyWith(include: include),
        ),
      ),
    );
  }

  /// Drops the current plan (options changed, dialog reopened, source set
  /// changed) so a stale preview can never be exported. While work is in
  /// flight, the request CANCELS it — the pending completion then refuses to
  /// publish a plan/result, and a fresh dialog starts clean.
  void reset() {
    if (_running) {
      _cancelRequested = true;
      return;
    }
    _plannedCategory = null;
    _plannedImages = null;
    _plannedCaptions = <String, String>{};
    emit(const MossTrainingExportInitial());
  }

  /// True when the plan no longer matches the current source set, category,
  /// OR the live caption texts of the planned images (a caption edited in
  /// the session after the audit invalidates the preview).
  bool isPlanStale({required List<AppImage> images, required String category}) {
    if (_plannedCategory != category) {
      return true;
    }
    final List<AppImage>? planned = _plannedImages;
    if (planned == null || planned.length != images.length) {
      return true;
    }
    for (int i = 0; i < planned.length; i++) {
      if (planned[i].id != images[i].id ||
          planned[i].image.path != images[i].image.path) {
        return true;
      }
      final String? expected = _plannedCaptions[planned[i].id];
      if (expected != null &&
          (images[i].captions[category]?.text ?? '') != expected) {
        return true;
      }
    }
    return false;
  }

  /// Executes the current plan and saves via the platform save dialog.
  /// Cancellation between images skips the save step entirely.
  ///
  /// [isStale] is called immediately before running — the caller wires it to
  /// LIVE session state (captions may have changed since the preview was
  /// audited); a stale preview refuses to export until it is rebuilt.
  Future<void> exportPlan({bool Function()? isStale}) async {
    final MossTrainingExportState current = state;
    if (current is! MossTrainingExportPlanned || _running) {
      return;
    }
    // Staleness gate against LIVE inputs (Codex rev-3 finding 1): the
    // preview was built from a snapshot; an edited caption in the session
    // invalidates it until the plan is rebuilt.
    if (isStale != null && isStale()) {
      emit(
        const MossTrainingExportError(
          message:
              'The preview is stale — a caption changed since it was built. '
              'Rebuild the plan before exporting.',
        ),
      );
      return;
    }
    _running = true;
    // Note: _cancelRequested is intentionally NOT reset here — a cancel
    // issued between buildPlan and exportPlan (or while the dialog was
    // closing) must still skip the run.
    emit(MossTrainingExporting(processed: 0, total: current.plan.items.length));
    try {
      final Either<Failure, (MossTrainingExportResult, Uint8List)>
      exportResult = await _repository.exportPlan(
        plan: current.plan,
        onProgress: (int processed, int total, String fileName) {
          if (isClosed) {
            return;
          }
          emit(
            MossTrainingExporting(
              processed: processed,
              total: total,
              currentImage: fileName,
            ),
          );
        },
        isCancelled: () => _cancelRequested || isClosed,
      );

      if (_cancelRequested || isClosed) {
        if (!isClosed) {
          emit(
            const MossTrainingExportDone(
              result: MossTrainingExportResult(
                imageCount: 0,
                captionCount: 0,
                droppedBoxCount: 0,
                warnings: <String>[],
                outputHashes: <String, String>{},
              ),
              saved: false,
              cancelled: true,
            ),
          );
        }
        return;
      }

      final Failure? failure = exportResult.getLeft().toNullable();
      if (failure != null) {
        if (!isClosed) {
          emit(
            MossTrainingExportError(
              message: failure.message ?? 'export failed',
            ),
          );
        }
        return;
      }

      final (MossTrainingExportResult, Uint8List) success = exportResult
          .getRight()
          .toNullable()!;
      bool saved = false;
      String? saveError;
      try {
        final String fileName =
            'moss-training-${current.plan.options.resolution}.zip';
        final String? downloadsPath = await getDownloadsDirectory().then(
          (Directory? dir) => dir?.path,
        );
        // Recheck after EVERY await crossing the save boundary: a cancel or
        // dispose during the directory lookup must not pop the platform
        // save dialog.
        if (_cancelRequested || isClosed) {
          emit(
            MossTrainingExportDone(
              result: success.$1,
              saved: false,
              cancelled: true,
            ),
          );
          return;
        }
        final Uri? outputFile = await FilePicker.saveFile(
          dialogTitle: 'Save MOSS training dataset',
          fileName: fileName,
          initialDirectory: downloadsPath,
          bytes: success.$2,
        );
        saved = outputFile != null;
      } catch (e) {
        saveError = 'save failed: $e';
      }
      if (isClosed) {
        return;
      }
      if (saveError != null) {
        emit(MossTrainingExportError(message: saveError));
      } else {
        emit(MossTrainingExportDone(result: success.$1, saved: saved));
      }
    } finally {
      _running = false;
    }
  }

  /// Stops the run at the next image boundary. Already-staged work is
  /// discarded by the exporter's cleanup; nothing is saved.
  void cancel() {
    _cancelRequested = true;
  }
}

sealed class MossTrainingExportState extends Equatable {
  const MossTrainingExportState();

  @override
  List<Object?> get props => <Object?>[];
}

class MossTrainingExportInitial extends MossTrainingExportState {
  const MossTrainingExportInitial();
}

class MossTrainingExportPlanning extends MossTrainingExportState {
  const MossTrainingExportPlanning();
}

class MossTrainingExportPlanned extends MossTrainingExportState {
  const MossTrainingExportPlanned(this.plan);

  final MossTrainingExportPlan plan;

  @override
  List<Object?> get props => <Object?>[plan];
}

class MossTrainingExporting extends MossTrainingExportState {
  const MossTrainingExporting({
    required this.processed,
    required this.total,
    this.currentImage,
  });

  final int processed;
  final int total;
  final String? currentImage;

  @override
  List<Object?> get props => <Object?>[processed, total, currentImage];
}

class MossTrainingExportDone extends MossTrainingExportState {
  const MossTrainingExportDone({
    required this.result,
    required this.saved,
    this.cancelled = false,
  });

  final MossTrainingExportResult result;
  final bool saved;
  final bool cancelled;

  @override
  List<Object?> get props => <Object?>[result, saved, cancelled];
}

class MossTrainingExportError extends MossTrainingExportState {
  const MossTrainingExportError({required this.message});

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

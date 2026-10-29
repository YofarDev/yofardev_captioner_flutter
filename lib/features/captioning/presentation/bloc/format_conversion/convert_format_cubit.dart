import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../../../core/models/app_image.dart';
import '../../../../../core/models/moss_format.dart';
import '../../../../../core/models/structured_caption_document.dart';
import '../../../../../core/services/moss_conversion_service.dart';
import '../../../../caption_session/caption_session.dart';
import 'convert_format_state.dart';

/// Local (no-LLM) batch conversion of structured captions between the
/// Ideogram and MOSS JSON formats, delegating every conversion to the shared
/// [MossConversionService] (exact source dimensions, structured diagnostics)
/// — the same implementation the Agent API uses.
///
/// Batch semantics:
/// - All jobs are captured (id + source text) before any write; writes go
///   through the session's id/category-targeted update against *current*
///   state, refusing when the source caption changed mid-run.
/// - Destination collisions are skipped unless [apply] is given
///   [overwriteExisting]; source==destination requires in-place mode.
/// - Overlapping runs are refused. Cancellation stops future work but never
///   undoes already-written captions; partial totals are reported.
class ConvertFormatCubit extends Cubit<ConvertFormatState> {
  ConvertFormatCubit(this._session, {MossConversionService? conversionService})
    : _conversionService = conversionService ?? MossConversionService(),
      super(const ConvertFormatInitial());

  final CaptionSessionService _session;
  final MossConversionService _conversionService;
  final Logger _logger = Logger('ConvertFormatCubit');
  Completer<void>? _cancelCompleter;
  bool _running = false;

  /// Converts captions in the active category toward [target].
  ///
  /// [inPlace] overwrites the existing captions; otherwise results land in
  /// [newCategoryName] (created when missing, defaulting to `moss` /
  /// `ideogram`). Existing destination captions are skipped unless
  /// [overwriteExisting] is set.
  Future<void> apply({
    required CaptionFormat target,
    required bool inPlace,
    String? newCategoryName,
    bool overwriteExisting = false,
  }) async {
    if (_running) {
      _logger.warning('apply: a conversion run is already in progress');
      return;
    }
    _running = true;
    _cancelCompleter = Completer<void>();
    try {
      await _run(
        target: target,
        inPlace: inPlace,
        newCategoryName: newCategoryName,
        overwriteExisting: overwriteExisting,
      );
    } finally {
      _cancelCompleter = null;
      _running = false;
    }
  }

  Future<void> _run({
    required CaptionFormat target,
    required bool inPlace,
    String? newCategoryName,
    required bool overwriteExisting,
  }) async {
    final String category = _session.state.activeCategory ?? 'default';
    final CaptionFormat source = target == CaptionFormat.moss
        ? CaptionFormat.ideogram
        : CaptionFormat.moss;

    // Capture jobs up front: image id + the exact source text seen now.
    final List<_ConversionJob> jobs = <_ConversionJob>[];
    for (final AppImage image in _session.state.images) {
      final String text = image.captions[category]?.text ?? '';
      if (detectCaptionFormat(text) != source) continue;
      jobs.add(
        _ConversionJob(
          imageId: image.id,
          fileName: p.basename(image.image.path),
          imagePath: image.image.path,
          sourceText: text,
        ),
      );
    }

    if (jobs.isEmpty) {
      emit(const ConvertFormatCompleted(converted: 0));
      return;
    }

    // Resolve the destination up front so a category-creation failure
    // aborts before any caption is written.
    final String fallbackName = target == CaptionFormat.moss
        ? 'moss'
        : 'ideogram';
    late final String destinationCategory;
    if (inPlace) {
      destinationCategory = category;
    } else {
      final String name = (newCategoryName?.trim().isNotEmpty ?? false)
          ? newCategoryName!.trim()
          : fallbackName;
      if (name == category) {
        emit(
          ConvertFormatError(
            message:
                'Target category equals the source category "$category" — '
                'enable "Overwrite in place" instead.',
          ),
        );
        return;
      }
      if (!_session.state.categories.contains(name)) {
        try {
          await _session.addCategory(name, format: 'json');
        } catch (e) {
          _logger.warning('addCategory failed: $e');
          emit(ConvertFormatError(message: 'Could not create category: $e'));
          return;
        }
      }
      destinationCategory = name;
    }

    final int total = jobs.length;
    int converted = 0;
    int skipped = 0;
    int failed = 0;
    final List<MossFormatDiagnostic> diagnostics = <MossFormatDiagnostic>[];

    void emitProgress(int processed, String? currentName) {
      emit(
        ConvertFormatInProgress(
          processedImages: processed,
          totalImages: total,
          currentImageName: currentName,
          converted: converted,
          skipped: skipped,
          failed: failed,
          diagnostics: List<MossFormatDiagnostic>.of(diagnostics),
        ),
      );
    }

    emitProgress(0, jobs.first.fileName);

    for (final _ConversionJob job in jobs) {
      if (_cancelCompleter?.isCompleted ?? false) {
        emit(
          ConvertFormatCompleted(
            converted: converted,
            skipped: skipped,
            failed: failed,
            cancelled: true,
            diagnostics: List<MossFormatDiagnostic>.of(diagnostics),
          ),
        );
        return;
      }

      emitProgress(converted + skipped + failed, job.fileName);

      // Collision policy: without an explicit overwrite choice, existing
      // destination captions are never touched.
      if (!inPlace && !overwriteExisting) {
        final AppImage? live = _findImage(job.imageId);
        final String existingDest =
            live?.captions[destinationCategory]?.text ?? '';
        if (existingDest.isNotEmpty) {
          skipped++;
          diagnostics.add(
            MossFormatDiagnostic(
              code: MossDiagnosticCodes.destinationCollision,
              severity: MossDiagnosticSeverity.info,
              message: 'destination caption already exists — skipped',
              imagePath: job.imagePath,
              suggestedAction:
                  'Re-run with "Overwrite existing" to replace it.',
            ),
          );
          continue;
        }
      }

      MossConversionOutcome outcome;
      try {
        outcome = await _conversionService.convert(
          text: job.sourceText,
          target: target,
          imageFile: File(job.imagePath),
        );
      } catch (e, st) {
        // One broken job (unreadable file, decode crash) must not leave the
        // run without a completion report.
        _logger.warning('convert crashed for ${job.fileName}: $e\n$st');
        failed++;
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.imageDimensionsUnknown,
            severity: MossDiagnosticSeverity.error,
            message: '${job.fileName}: conversion failed: $e',
            imagePath: job.imagePath,
          ),
        );
        continue;
      }
      if (outcome.skippedReason != null) {
        skipped++;
        continue;
      }
      if (outcome.fatal) {
        failed++;
        diagnostics.addAll(outcome.diagnostics);
        _logger.warning(
          'convert failed for ${job.fileName}: ${outcome.diagnostics}',
        );
        continue;
      }

      // Final-write guards against CURRENT state: the source caption may
      // have changed while we were converting, and a destination caption may
      // have appeared in the meantime (both would otherwise be clobbered).
      final AppImage? live = _findImage(job.imageId);
      final String liveSource = live?.captions[category]?.text ?? '';
      if (liveSource != job.sourceText) {
        skipped++;
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.sourceChangedDuringConversion,
            severity: MossDiagnosticSeverity.warning,
            message:
                'source caption changed during conversion — result not '
                'written',
            imagePath: job.imagePath,
          ),
        );
        continue;
      }
      if (!inPlace &&
          !overwriteExisting &&
          (live?.captions[destinationCategory]?.text.isNotEmpty ?? false)) {
        skipped++;
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.destinationCollision,
            severity: MossDiagnosticSeverity.info,
            message: 'destination caption appeared during conversion — skipped',
            imagePath: job.imagePath,
            suggestedAction: 'Re-run with "Overwrite existing" to replace it.',
          ),
        );
        continue;
      }

      // Apply against current state; refuse when the source caption changed
      // while we were converting (unrelated concurrent edit protection).
      bool written;
      try {
        written = await _session.updateImageCaption(
          imageId: job.imageId,
          category: destinationCategory,
          text: outcome.text!,
          model: target == CaptionFormat.moss
              ? 'ideogram→moss'
              : 'moss→ideogram',
          sourceCategory: category,
          expectedSourceText: job.sourceText,
        );
      } catch (e, st) {
        // A persistence failure on one image must not abort the run without
        // a completion report.
        _logger.warning('write failed for ${job.fileName}: $e\n$st');
        failed++;
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.imageDimensionsUnknown,
            severity: MossDiagnosticSeverity.error,
            message: '${job.fileName}: write failed: $e',
            imagePath: job.imagePath,
          ),
        );
        continue;
      }
      if (!written) {
        skipped++;
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.sourceChangedDuringConversion,
            severity: MossDiagnosticSeverity.warning,
            message:
                'source caption changed during conversion — result not '
                'written',
            imagePath: job.imagePath,
          ),
        );
        continue;
      }
      converted++;
      diagnostics.addAll(outcome.diagnostics);
    }

    emit(
      ConvertFormatCompleted(
        converted: converted,
        skipped: skipped,
        failed: failed,
        diagnostics: List<MossFormatDiagnostic>.of(diagnostics),
      ),
    );
  }

  AppImage? _findImage(String imageId) {
    for (final AppImage image in _session.state.images) {
      if (image.id == imageId) {
        return image;
      }
    }
    return null;
  }

  void cancel() {
    _cancelCompleter?.complete();
  }
}

class _ConversionJob {
  const _ConversionJob({
    required this.imageId,
    required this.fileName,
    required this.imagePath,
    required this.sourceText,
  });

  final String imageId;
  final String fileName;
  final String imagePath;
  final String sourceText;
}

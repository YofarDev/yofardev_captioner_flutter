import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../../../core/models/app_image.dart';
import '../../../../../core/models/caption_entry.dart';
import '../../../../../core/models/moss_conversion.dart';
import '../../../../../core/models/moss_format.dart';
import '../../../../../core/models/moss_layout_caption.dart';
import '../../../../../core/models/moss_repair.dart';
import '../../../../../core/models/structured_caption_document.dart';
import '../../../../../core/services/image_dimension_resolver.dart';
import '../../../../../core/services/moss_conversion_service.dart';
import '../../../../caption_session/caption_session.dart';
import 'legacy_moss_repair_state.dart';

/// Read-only audit + reviewable repair for MOSS drafts produced by the
/// historical 16-pixel-rounded conversion (P1: virtual canvas ≠ copied
/// image).
///
/// Strategies, in preference order:
/// 1. [MossRepairStrategy.reconvert] — a discoverable Ideogram source caption
///    exists (category + text captured at audit time) and the reviewer accepts
///    reconverting from it. Both the Ideogram text and the MOSS text are
///    guarded against changes before writing. The Ideogram category is
///    preserved; results go to a separate destination category by default.
/// 2. [MossRepairStrategy.rescaleFrame] — the draft canvas is exactly the
///    legacy rounded frame of the real source. MOSS wording and item
///    metadata are preserved verbatim; boxes are scaled by `actual / draft`
///    per axis with documented rounding. Presented as an explicit assumption,
///    never applied to arbitrary mismatches.
///
/// The `isEdited` flag alone never decides a strategy (initial conversions
/// also set it); the reviewer can override each row's strategy before
/// applying. Preview categories are bound at audit time — Apply reuses
/// exactly those, never the currently active category. Writes go through the
/// live session (never external db.json patching), and per-job failures are
/// reported without aborting the run.
class RepairLegacyMossCubit extends Cubit<LegacyMossRepairState> {
  RepairLegacyMossCubit(
    this._session, {
    MossConversionService? conversionService,
  }) : _conversionService = conversionService ?? MossConversionService(),
       super(const LegacyMossRepairInitial());

  final CaptionSessionService _session;
  final MossConversionService _conversionService;
  final ImageDimensionResolver _dimensionResolver =
      const ImageDimensionResolver();
  final Logger _logger = Logger('RepairLegacyMossCubit');
  Completer<void>? _cancelCompleter;
  bool _running = false;

  /// Audits every MOSS draft in [sourceCategory] against the real decoded
  /// image dimensions and emits a [LegacyMossRepairPreview] with categories
  /// and source texts captured.
  Future<void> audit({
    String? sourceCategory,
    String destinationCategory = 'moss-repaired',
  }) async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      await _audit(
        sourceCategory: sourceCategory,
        destinationCategory: destinationCategory,
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _audit({
    String? sourceCategory,
    required String destinationCategory,
  }) async {
    final String category =
        sourceCategory ?? _session.state.activeCategory ?? 'default';
    final List<MossRepairCandidate> candidates = <MossRepairCandidate>[];
    final List<MossFormatDiagnostic> diagnostics = <MossFormatDiagnostic>[];

    for (final AppImage image in _session.state.images) {
      final String text = image.captions[category]?.text ?? '';
      if (!MossLayoutCaption.isMossJson(text)) {
        continue;
      }
      if (MossLayoutCaption.isNativeMossJson(text)) {
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.nativeMarkersInDraftPath,
            severity: MossDiagnosticSeverity.info,
            message: 'native prompt — not a draft, skipped',
            imagePath: image.image.path,
          ),
        );
        continue;
      }
      final ImageDimensions? dims;
      try {
        dims = await _dimensionResolver.resolve(image.image);
      } catch (e) {
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.imageDimensionsUnknown,
            severity: MossDiagnosticSeverity.warning,
            message: 'image dimensions unreadable: $e',
            imagePath: image.image.path,
          ),
        );
        continue;
      }
      if (dims == null) {
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.imageDimensionsUnknown,
            severity: MossDiagnosticSeverity.warning,
            message: 'image dimensions unreadable — cannot audit',
            imagePath: image.image.path,
          ),
        );
        continue;
      }
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      parsed = parseMossDraft(text, imagePath: image.image.path);
      if (parsed.caption == null) {
        diagnostics.addAll(parsed.diagnostics);
        continue;
      }
      final MossLayoutCaption draft = parsed.caption!;
      final MossFrameAuditResult frame = auditMossFrame(
        draftWidth: draft.width,
        draftHeight: draft.height,
        actualWidth: dims.width,
        actualHeight: dims.height,
      );
      final String? ideogramCategory = _ideogramSourceFor(
        image,
        exclude: category,
      );
      final String? ideogramText = ideogramCategory == null
          ? null
          : (image.captions[ideogramCategory]?.text ?? '');
      final MossRepairStrategy strategy;
      String detail;
      switch (frame) {
        case MossFrameAuditResult.exact:
          strategy = MossRepairStrategy.none;
          detail = 'Canvas already matches the image; nothing to repair.';
        case MossFrameAuditResult.legacyRounded:
          if (ideogramCategory != null && ideogramText!.isNotEmpty) {
            // Deliberate default (Codex rev-2 finding 4): reconversion
            // discards post-conversion MOSS wording edits, so it is only
            // the default when the draft carries no edited flag; otherwise
            // rescale (which preserves wording/metadata) is the default and
            // reconversion is a per-row choice.
            final bool edited = image.captions[category]?.isEdited ?? false;
            if (edited) {
              strategy = MossRepairStrategy.rescaleFrame;
              detail =
                  'Legacy rounded frame and the draft carries the edited '
                  'flag — default RESCALES boxes to the real frame, keeping '
                  'your wording/metadata. Choose "Reconvert" to discard '
                  'edits and rebuild from the Ideogram source in '
                  '"$ideogramCategory".';
            } else {
              strategy = MossRepairStrategy.reconvert;
              detail =
                  'Legacy rounded frame; Ideogram source found in '
                  '"$ideogramCategory" and the draft is unedited — '
                  'reconvert from it (source category is preserved).';
            }
          } else {
            strategy = MossRepairStrategy.rescaleFrame;
            detail =
                'Legacy rounded frame, no Ideogram source — scale boxes to '
                'the real frame, keeping all wording/metadata (assumption: '
                'legacy rounding).';
          }
        case MossFrameAuditResult.mismatch:
          strategy = MossRepairStrategy.skip;
          detail =
              'Draft canvas disagrees with the image in a non-legacy way '
              '(changed image or imported layout) — no automatic repair.';
      }
      // Compute the rescale preview for the overlay regardless of strategy —
      // the reviewer may switch a row to rescale.
      final ({
        MossLayoutCaption caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      rescaled = rescaleMossDraftFrame(
        draft,
        actualWidth: dims.width,
        actualHeight: dims.height,
        imagePath: image.image.path,
      );
      // Reconversion box preview: Ideogram source boxes projected onto the
      // real frame (what "Reconvert" would produce).
      List<List<int>?> reconvertPreview = const <List<int>?>[];
      if (ideogramCategory != null && (ideogramText ?? '').isNotEmpty) {
        final Object? srcDoc = StructuredCaptionDocument.tryParse(
          ideogramText!,
        );
        if (srcDoc is IdeogramDocument) {
          final MossFromIdeogramResult converted = mossFromIdeogram(
            srcDoc.caption,
            width: dims.width,
            height: dims.height,
            imagePath: image.image.path,
          );
          reconvertPreview = converted.caption.items
              .map((MossItem i) => i.bbox)
              .toList();
        }
      }
      candidates.add(
        MossRepairCandidate(
          imageId: image.id,
          fileName: p.basename(image.image.path),
          imagePath: image.image.path,
          strategy: strategy,
          draftWidth: draft.width,
          draftHeight: draft.height,
          actualWidth: dims.width,
          actualHeight: dims.height,
          itemCount: draft.items.length,
          mossText: text,
          sourceCategory: category,
          destinationCategory: destinationCategory,
          mossEdited: image.captions[category]?.isEdited ?? false,
          ideogramSourceCategory: ideogramCategory,
          ideogramSourceText: ideogramText,
          detail: detail,
          repairedPreview: rescaled.caption.items
              .map((MossItem i) => i.bbox)
              .toList(),
          reconvertPreview: reconvertPreview,
        ),
      );
    }

    emit(
      LegacyMossRepairPreview(
        candidates: candidates,
        diagnostics: diagnostics,
        sourceCategory: category,
        destinationCategory: destinationCategory,
      ),
    );
  }

  /// Reviewer override: change one row's strategy (and recompute its
  /// explanation) before applying.
  void setStrategy(int index, MossRepairStrategy strategy) {
    final LegacyMossRepairState current = state;
    if (current is! LegacyMossRepairPreview) {
      return;
    }
    if (index < 0 || index >= current.candidates.length) {
      return;
    }
    final MossRepairCandidate c = current.candidates[index];
    if (strategy == MossRepairStrategy.reconvert &&
        (c.ideogramSourceCategory == null ||
            (c.ideogramSourceText ?? '').isEmpty)) {
      // Cannot reconvert without a captured Ideogram source.
      return;
    }
    String detail;
    switch (strategy) {
      case MossRepairStrategy.reconvert:
        detail =
            'Reviewer-selected: reconvert from the Ideogram source in '
            '"${c.ideogramSourceCategory}".';
      case MossRepairStrategy.rescaleFrame:
        detail =
            'Reviewer-selected: scale boxes to the real frame, keeping '
            'all wording/metadata (assumption: legacy rounding).';
      case MossRepairStrategy.none:
      case MossRepairStrategy.skip:
        detail = 'Reviewer-selected: skip this row.';
    }
    emit(
      current.withCandidate(
        index,
        c.copyWith(strategy: strategy, detail: detail),
      ),
    );
  }

  /// Finds an Ideogram-format caption category for [image] other than
  /// [exclude].
  String? _ideogramSourceFor(AppImage image, {required String exclude}) {
    for (final MapEntry<String, CaptionEntry> entry in image.captions.entries) {
      if (entry.key == exclude) {
        continue;
      }
      if (entry.value.text.isEmpty) {
        continue;
      }
      if (detectCaptionFormat(entry.value.text) == CaptionFormat.ideogram) {
        return entry.key;
      }
    }
    return null;
  }

  /// Applies the previewed repairs into the preview-bound destination
  /// category. Cancellation stops future work; written results are kept.
  /// Per-job failures are reported and do not abort the run.
  Future<void> applyRepairs({bool overwriteDestination = false}) async {
    final LegacyMossRepairState current = state;
    if (current is! LegacyMossRepairPreview) {
      return;
    }
    if (_running) {
      return;
    }
    _running = true;
    _cancelCompleter = Completer<void>();
    try {
      await _applyRepairs(current, overwriteDestination: overwriteDestination);
    } finally {
      _cancelCompleter = null;
      _running = false;
    }
  }

  Future<void> _applyRepairs(
    LegacyMossRepairPreview preview, {
    required bool overwriteDestination,
  }) async {
    final String destinationCategory = preview.destinationCategory;
    final String sourceCategory = preview.sourceCategory;
    final List<MossRepairCandidate> jobs = preview.candidates
        .where(
          (MossRepairCandidate c) =>
              c.strategy == MossRepairStrategy.reconvert ||
              c.strategy == MossRepairStrategy.rescaleFrame,
        )
        .toList();
    if (jobs.isEmpty) {
      emit(const LegacyMossRepairCompleted(repaired: 0, skipped: 0));
      return;
    }
    if (!_session.state.categories.contains(destinationCategory)) {
      try {
        await _session.addCategory(destinationCategory, format: 'json');
      } catch (e) {
        _logger.warning('addCategory failed: $e');
        emit(
          LegacyMossRepairCompleted(
            repaired: 0,
            skipped: jobs.length,
            fatalError: 'Could not create category: $e',
          ),
        );
        return;
      }
    }

    int repaired = 0;
    int skipped = 0;
    int failed = 0;
    final List<MossFormatDiagnostic> diagnostics =
        List<MossFormatDiagnostic>.of(preview.diagnostics);

    for (int i = 0; i < jobs.length; i++) {
      if (_cancelCompleter?.isCompleted ?? false) {
        emit(
          LegacyMossRepairCompleted(
            repaired: repaired,
            skipped: skipped,
            failed: failed,
            cancelled: true,
            diagnostics: diagnostics,
          ),
        );
        return;
      }
      emit(
        LegacyMossRepairInProgress(
          processed: i,
          total: jobs.length,
          repaired: repaired,
          skipped: skipped,
          failed: failed,
        ),
      );
      final MossRepairCandidate job = jobs[i];

      try {
        final AppImage? live = _findImage(job.imageId);
        final String currentMoss = live?.captions[sourceCategory]?.text ?? '';
        if (currentMoss.isEmpty) {
          skipped++;
          continue;
        }
        // Guard BOTH sources: the MOSS text this row audited, and (for
        // reconversion) the captured Ideogram text.
        if (currentMoss != job.mossText) {
          skipped++;
          diagnostics.add(
            MossFormatDiagnostic(
              code: MossDiagnosticCodes.sourceChangedDuringConversion,
              severity: MossDiagnosticSeverity.warning,
              message:
                  '${job.fileName}: MOSS caption changed since audit — '
                  're-audit before repairing',
              imagePath: job.imagePath,
            ),
          );
          continue;
        }
        if (job.strategy == MossRepairStrategy.reconvert) {
          final String currentIdeogram =
              live?.captions[job.ideogramSourceCategory!]?.text ?? '';
          if (currentIdeogram.isEmpty ||
              currentIdeogram != job.ideogramSourceText) {
            skipped++;
            diagnostics.add(
              MossFormatDiagnostic(
                code: MossDiagnosticCodes.sourceChangedDuringConversion,
                severity: MossDiagnosticSeverity.warning,
                message:
                    '${job.fileName}: Ideogram source changed since audit — '
                    're-audit before repairing',
                imagePath: job.imagePath,
              ),
            );
            continue;
          }
        }
        if (!overwriteDestination &&
            (live?.captions[destinationCategory]?.text.isNotEmpty ?? false)) {
          skipped++;
          diagnostics.add(
            MossFormatDiagnostic(
              code: MossDiagnosticCodes.destinationCollision,
              severity: MossDiagnosticSeverity.info,
              message:
                  '${job.fileName}: destination caption already exists — '
                  'skipped',
              imagePath: job.imagePath,
            ),
          );
          continue;
        }

        final String? repairedText;
        final String modelTag;
        switch (job.strategy) {
          case MossRepairStrategy.reconvert:
            // Convert the CAPTURED IDEOGRAM TEXT — never the MOSS caption
            // (which is already the target format and would be skipped).
            final MossConversionOutcome outcome = await _conversionService
                .convert(
                  text: job.ideogramSourceText!,
                  target: CaptionFormat.moss,
                  imageFile: File(job.imagePath),
                );
            repairedText = outcome.text;
            modelTag = 'moss-repair:reconvert';
            if (outcome.text == null) {
              skipped++;
              diagnostics.addAll(outcome.diagnostics);
              continue;
            }
          case MossRepairStrategy.rescaleFrame:
            final ImageDimensions? dims = await _dimensionResolver.resolve(
              File(job.imagePath),
            );
            if (dims == null) {
              failed++;
              diagnostics.add(
                MossFormatDiagnostic(
                  code: MossDiagnosticCodes.imageDimensionsUnknown,
                  severity: MossDiagnosticSeverity.error,
                  message: '${job.fileName}: dimensions unreadable',
                  imagePath: job.imagePath,
                ),
              );
              continue;
            }
            final ({
              MossLayoutCaption caption,
              List<MossFormatDiagnostic> diagnostics,
            })
            rescaled = rescaleMossDraftFrame(
              (StructuredCaptionDocument.tryParse(job.mossText)!
                      as MossDocument)
                  .caption,
              actualWidth: dims.width,
              actualHeight: dims.height,
              imagePath: job.imagePath,
            );
            repairedText = rescaled.caption.toJsonString();
            modelTag = 'moss-repair:rescale';
            diagnostics.addAll(rescaled.diagnostics);
          case MossRepairStrategy.none:
          case MossRepairStrategy.skip:
            skipped++;
            continue;
        }

        // POST-AWAIT recheck (Codex rev-2 finding 6): the conversion and
        // dimension lookups above are awaited — Ideogram source and
        // destination may have changed during that time. Re-verify BOTH
        // immediately before committing; updateImageCaption's
        // expectedSourceText remains the final seatbelt for the MOSS side.
        final AppImage? rechecked = _findImage(job.imageId);
        if (rechecked == null ||
            (rechecked.captions[sourceCategory]?.text ?? '') != job.mossText) {
          skipped++;
          diagnostics.add(
            MossFormatDiagnostic(
              code: MossDiagnosticCodes.sourceChangedDuringConversion,
              severity: MossDiagnosticSeverity.warning,
              message:
                  '${job.fileName}: MOSS caption changed during repair — '
                  'result not written; re-audit',
              imagePath: job.imagePath,
            ),
          );
          continue;
        }
        if (job.strategy == MossRepairStrategy.reconvert) {
          final String liveIdeogram =
              rechecked.captions[job.ideogramSourceCategory!]?.text ?? '';
          if (liveIdeogram != job.ideogramSourceText) {
            skipped++;
            diagnostics.add(
              MossFormatDiagnostic(
                code: MossDiagnosticCodes.sourceChangedDuringConversion,
                severity: MossDiagnosticSeverity.warning,
                message:
                    '${job.fileName}: Ideogram source changed during repair '
                    '— result not written; re-audit',
                imagePath: job.imagePath,
              ),
            );
            continue;
          }
        }
        if (!overwriteDestination &&
            (rechecked.captions[destinationCategory]?.text.isNotEmpty ??
                false)) {
          skipped++;
          diagnostics.add(
            MossFormatDiagnostic(
              code: MossDiagnosticCodes.destinationCollision,
              severity: MossDiagnosticSeverity.info,
              message:
                  '${job.fileName}: destination caption appeared during '
                  'repair — skipped',
              imagePath: job.imagePath,
            ),
          );
          continue;
        }

        final bool written = await _session.updateImageCaption(
          imageId: job.imageId,
          category: destinationCategory,
          text: repairedText!,
          model: modelTag,
          sourceCategory: sourceCategory,
          expectedSourceText: job.mossText,
        );
        if (!written) {
          skipped++;
          diagnostics.add(
            MossFormatDiagnostic(
              code: MossDiagnosticCodes.sourceChangedDuringConversion,
              severity: MossDiagnosticSeverity.warning,
              message:
                  '${job.fileName}: source caption changed during repair — '
                  'result not written',
              imagePath: job.imagePath,
            ),
          );
          continue;
        }
        repaired++;
      } catch (e, st) {
        // One broken job must never leave the run without a completion
        // report.
        _logger.warning('repair job failed for ${job.fileName}: $e\n$st');
        failed++;
        diagnostics.add(
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.notMossJson,
            severity: MossDiagnosticSeverity.error,
            message: '${job.fileName}: repair failed: $e',
            imagePath: job.imagePath,
          ),
        );
      }
    }

    emit(
      LegacyMossRepairCompleted(
        repaired: repaired,
        skipped: skipped,
        failed: failed,
        diagnostics: diagnostics,
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

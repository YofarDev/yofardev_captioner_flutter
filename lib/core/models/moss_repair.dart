import 'moss_conversion.dart';
import 'moss_format.dart';
import 'moss_layout_caption.dart';

/// How a stored MOSS draft's declared canvas relates to the real decoded
/// source image.
enum MossFrameAuditResult {
  /// Draft canvas equals the exact source dimensions — nothing to repair.
  exact,

  /// Draft canvas equals the historical 16-pixel-rounded frame
  /// (`mossCanvasSize`) of the source — a known legacy conversion artifact
  /// that frame reconciliation can repair.
  legacyRounded,

  /// Any other disagreement — likely a changed image or an imported layout;
  /// frame scaling is NOT a safe assumption here.
  mismatch,
}

/// Classifies a draft canvas against real source dimensions.
MossFrameAuditResult auditMossFrame({
  required int draftWidth,
  required int draftHeight,
  required int actualWidth,
  required int actualHeight,
}) {
  if (draftWidth == actualWidth && draftHeight == actualHeight) {
    return MossFrameAuditResult.exact;
  }
  final (int, int) legacy = mossCanvasSize(
    imageWidth: actualWidth,
    imageHeight: actualHeight,
  );
  if (draftWidth == legacy.$1 && draftHeight == legacy.$2) {
    return MossFrameAuditResult.legacyRounded;
  }
  return MossFrameAuditResult.mismatch;
}

/// The chosen strategy for repairing one legacy MOSS draft.
enum MossRepairStrategy {
  /// Draft already matches the source; no write needed.
  none,

  /// Reconvert from the surviving Ideogram source caption (preferred when
  /// available and the MOSS draft has no meaningful edits).
  reconvert,

  /// Reconcile the frame: keep MOSS wording and item metadata verbatim and
  /// scale boxes by `actual / draft` per axis. An explicit assumption for
  /// legacy rounded frames — never applied to arbitrary mismatches.
  rescaleFrame,

  /// No safe automatic strategy (mismatch, unreadable image, native prompt).
  skip,
}

/// Scales a draft's boxes from its declared frame to the real source frame,
/// rounding outward (floor left/top, ceil right/bottom) and clamping.
/// Summary wording, meta, palettes, labels, tags, and item order are
/// preserved verbatim.
///
/// Returns null diagnostics-free when every box survives; zero-area results
/// are reported per item and dropped. This transform is lossy at integer
/// level — callers must present it as "repaired with quantization", never
/// as lossless recovery.
({MossLayoutCaption caption, List<MossFormatDiagnostic> diagnostics})
rescaleMossDraftFrame(
  MossLayoutCaption draft, {
  required int actualWidth,
  required int actualHeight,
  String? imagePath,
}) {
  final double sx = actualWidth / draft.width;
  final double sy = actualHeight / draft.height;
  final List<MossFormatDiagnostic> diagnostics = <MossFormatDiagnostic>[];
  final List<MossItem> items = <MossItem>[];
  for (int i = 0; i < draft.items.length; i++) {
    final MossItem item = draft.items[i];
    final List<int>? bbox = item.bbox;
    if (bbox == null || bbox.length != 4) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.itemDropped,
          severity: MossDiagnosticSeverity.warning,
          message: 'item without a 4-number bbox dropped during frame repair',
          imagePath: imagePath,
          itemIndex: i,
        ),
      );
      continue;
    }
    final int x1 = (bbox[0] * sx).floor().clamp(0, actualWidth);
    final int y1 = (bbox[1] * sy).floor().clamp(0, actualHeight);
    final int x2 = (bbox[2] * sx).ceil().clamp(0, actualWidth);
    final int y2 = (bbox[3] * sy).ceil().clamp(0, actualHeight);
    if (x1 >= x2 || y1 >= y2) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.zeroAreaBbox,
          severity: MossDiagnosticSeverity.warning,
          message: 'box collapsed to zero area after rescale and was dropped',
          imagePath: imagePath,
          itemIndex: i,
        ),
      );
      continue;
    }
    items.add(item.copyWith(bbox: <int>[x1, y1, x2, y2]));
  }
  return (
    caption: draft.copyWith(
      width: actualWidth,
      height: actualHeight,
      items: items,
    ),
    diagnostics: diagnostics,
  );
}

import 'ideogram_caption.dart';
import 'moss_format.dart';
import 'moss_layout_caption.dart';

/// Ideogram4 → MOSS layout conversion.
///
/// Mapping (documented, deliberately lossy in spots):
/// - `high_level_description` + `background` → `summary.caption` (the
///   background sentence is appended; MOSS has no background slot).
/// - `medium` / `aesthetics` / `lighting` / `photo`/`art_style` →
///   `summary.meta` as flat tag strings.
/// - style `color_palette` → `summary.palette`.
/// - elements keep their order; `type: obj` → `label: object`, `type: text` →
///   `label: text`. Elements **without** a valid bbox are dropped and
///   reported in the result's diagnostics.
/// - bboxes: Ideogram `[y1, x1, y2, x2]` 0–1000 normalized → MOSS
///   `[x1, y1, x2, y2]` absolute pixels against the given canvas size,
///   clamped to the canvas; degenerate boxes (zero area after rounding) are
///   widened to 1px where the canvas allows, else dropped.
/// - [width]/[height] must be the **exact decoded source dimensions** — this
///   function never snaps or guesses geometry. Canvas alignment for training
///   belongs to dataset preparation, not annotation conversion.
MossFromIdeogramResult mossFromIdeogram(
  IdeogramCaption caption, {
  required int width,
  required int height,
  String? imagePath,
}) {
  final List<MossFormatDiagnostic> diagnostics = <MossFormatDiagnostic>[];
  final String background = caption.compositionalDeconstruction.background;
  if (background.isNotEmpty) {
    diagnostics.add(
      MossFormatDiagnostic(
        code: MossDiagnosticCodes.lossyContentMapping,
        severity: MossDiagnosticSeverity.info,
        message:
            'Ideogram background sentence folded into the MOSS summary '
            'caption (MOSS has no background slot)',
        imagePath: imagePath,
      ),
    );
  }
  final String summaryCaption = background.isEmpty
      ? caption.highLevelDescription
      : '${caption.highLevelDescription} $background';

  final IdeogramStyleDescription style = caption.styleDescription;
  final List<String> meta = <String>[
    style.medium,
    ...style.aesthetics
        .split(',')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty),
    if (style.lighting.isNotEmpty) style.lighting,
    if (style.medium == 'photograph' && style.photo?.isNotEmpty == true)
      style.photo!,
    if (style.medium != 'photograph' && style.artStyle?.isNotEmpty == true)
      style.artStyle!,
  ];

  final List<MossItem> items = <MossItem>[];
  for (final IdeogramElement element
      in caption.compositionalDeconstruction.elements) {
    final List<int>? ideogramBbox = element.bbox;
    if (ideogramBbox == null || ideogramBbox.length != 4) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.itemDropped,
          severity: MossDiagnosticSeverity.warning,
          message:
              'element without a 4-number bbox dropped: '
              '"${element.desc.isEmpty ? '<no description>' : element.desc}"',
          imagePath: imagePath,
          suggestedAction: 'Draw a bbox for the element or accept the loss.',
        ),
      );
      continue;
    }
    if (ideogramBbox[0] > ideogramBbox[2] ||
        ideogramBbox[1] > ideogramBbox[3]) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.reversedBbox,
          severity: MossDiagnosticSeverity.warning,
          message:
              'reversed normalized bbox $ideogramBbox corner-ordered before '
              'projection',
          imagePath: imagePath,
        ),
      );
    }
    final bool isText = element.type == 'text';
    final List<int>? bbox = normalizedToPixelBbox(
      ideogramBbox,
      width: width,
      height: height,
    );
    if (bbox == null) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.zeroAreaBbox,
          severity: MossDiagnosticSeverity.warning,
          message:
              'bbox of "${element.desc.isEmpty ? '<no description>' : element.desc}" '
              'collapses to zero area and was dropped',
          imagePath: imagePath,
        ),
      );
      continue;
    }
    items.add(
      MossItem(
        label: isText ? 'text' : 'object',
        caption: element.desc,
        text: isText ? (element.text ?? '') : null,
        bbox: bbox,
        palette: element.colorPalette ?? <String>[],
      ),
    );
  }

  return MossFromIdeogramResult(
    caption: MossLayoutCaption(
      width: width,
      height: height,
      summary: MossSummary(
        caption: summaryCaption,
        meta: meta,
        palette: style.colorPalette,
      ),
      items: items,
    ),
    diagnostics: diagnostics,
  );
}

/// Result of [mossFromIdeogram]: the converted layout plus structured
/// diagnostics for everything that was dropped, repaired, or lossy-mapped.
class MossFromIdeogramResult {
  const MossFromIdeogramResult({
    required this.caption,
    required this.diagnostics,
  });

  final MossLayoutCaption caption;
  final List<MossFormatDiagnostic> diagnostics;

  int get droppedItems => diagnostics
      .where(
        (MossFormatDiagnostic d) =>
            d.code == MossDiagnosticCodes.itemDropped ||
            d.code == MossDiagnosticCodes.zeroAreaBbox,
      )
      .length;
}

/// MOSS layout → Ideogram4 caption conversion (the inverse of
/// [mossFromIdeogram]).
///
/// - `summary.caption` → `high_level_description`; there is no reverse slot
///   for the Ideogram `background` (it was folded into the MOSS summary), so
///   it stays empty.
/// - `medium` is recovered from `summary.meta` when it carries one of the
///   five known Ideogram tokens (default `photograph`); the remaining meta
///   tags become `aesthetics` (lighting has no reliable reverse — the meta
///   list is unordered).
/// - `summary.palette` → style `color_palette`.
/// - items keep their order; `label: text` → `type: text`, everything else
///   (`object`, `character`) → `type: obj`.
/// - bboxes: absolute pixels → `[y1, x1, y2, x2]` 0–1000 normalized, clamped.
MossToIdeogramResult ideogramFromMoss(MossLayoutCaption moss) {
  const List<String> knownMediums = <String>[
    'photograph',
    'illustration',
    '3d_render',
    'painting',
    'graphic_design',
  ];

  final String? mediumToken = moss.summary.meta.cast<String?>().firstWhere(
    (String? tag) => knownMediums.contains(tag),
    orElse: () => null,
  );
  final List<String> remainingMeta = moss.summary.meta
      .where((String tag) => tag != mediumToken)
      .toList();

  final IdeogramStyleDescription style = IdeogramStyleDescription(
    aesthetics: remainingMeta.join(', '),
    lighting: '',
    medium: mediumToken ?? 'photograph',
    colorPalette: moss.summary.palette,
  );

  final List<IdeogramElement> elements = <IdeogramElement>[];
  int droppedItems = 0;
  for (final MossItem item in moss.items) {
    final List<int>? bbox = item.bbox;
    if (bbox == null || bbox.length != 4) {
      droppedItems++;
      continue;
    }
    final bool isText = item.label == 'text';
    elements.add(
      IdeogramElement(
        type: isText ? 'text' : 'obj',
        bbox: _pixelToNormalizedBbox(bbox, moss.width, moss.height),
        desc: item.caption,
        text: isText ? (item.text ?? '') : null,
      ),
    );
  }

  final IdeogramCaption caption = IdeogramCaption(
    highLevelDescription: moss.summary.caption,
    styleDescription: style,
    compositionalDeconstruction: IdeogramCompositionalDeconstruction(
      background: '',
      elements: elements,
    ),
  );
  return MossToIdeogramResult(caption: caption, droppedItems: droppedItems);
}

/// Snaps dimensions to positive multiples of 16. **No longer used by
/// conversion or generation** — those project onto exact source dimensions.
/// Retained for the legacy repair audit, which detects drafts whose canvas
/// was produced by this historical rounding rule.
(int, int) mossCanvasSize({required int imageWidth, required int imageHeight}) {
  int snap(int n) {
    if (n <= 0) return 16;
    final int snapped = (n / 16).round() * 16;
    return snapped < 16 ? 16 : snapped;
  }

  return (snap(imageWidth), snap(imageHeight));
}

/// Ideogram `[y1, x1, y2, x2]` 0–1000 normalized → MOSS `[x1, y1, x2, y2]`
/// absolute pixels. Returns null when the box degenerates to zero area after
/// rounding and cannot be widened inside the canvas.
List<int>? normalizedToPixelBbox(
  List<int> bbox, {
  required int width,
  required int height,
}) {
  final int y1 = bbox[0];
  final int x1 = bbox[1];
  final int y2 = bbox[2];
  final int x2 = bbox[3];
  int px1 = (x1 / 1000 * width).round().clamp(0, width);
  int py1 = (y1 / 1000 * height).round().clamp(0, height);
  int px2 = (x2 / 1000 * width).round().clamp(0, width);
  int py2 = (y2 / 1000 * height).round().clamp(0, height);
  if (px1 >= px2) {
    if (px2 < width) {
      px2 = px1 + 1;
    } else if (px1 > 0) {
      px1 = px2 - 1;
    } else {
      return null;
    }
  }
  if (py1 >= py2) {
    if (py2 < height) {
      py2 = py1 + 1;
    } else if (py1 > 0) {
      py1 = py2 - 1;
    } else {
      return null;
    }
  }
  return <int>[px1, py1, px2, py2];
}

/// MOSS `[x1, y1, x2, y2]` absolute pixels → Ideogram `[y1, x1, y2, x2]`
/// 0–1000 normalized, clamped and corner-ordered.
List<int> _pixelToNormalizedBbox(List<int> bbox, int width, int height) {
  int norm(int value, int dimension) =>
      (value / dimension * 1000).round().clamp(0, 1000);
  final int y1 = norm(bbox[1], height);
  final int x1 = norm(bbox[0], width);
  final int y2 = norm(bbox[3], height);
  final int x2 = norm(bbox[2], width);
  return <int>[
    if (y1 < y2) y1 else y2,
    if (x1 < x2) x1 else x2,
    if (y1 < y2) y2 else y1,
    if (x1 < x2) x2 else x1,
  ];
}

/// Result of [ideogramFromMoss]: the converted caption plus the count of MOSS
/// items dropped for missing bboxes (MOSS requires one per item; Ideogram
/// tolerates their absence, so the loss is reported rather than silent).
class MossToIdeogramResult {
  const MossToIdeogramResult({
    required this.caption,
    required this.droppedItems,
  });

  final IdeogramCaption caption;
  final int droppedItems;
}

/// Index-preserving MOSS → Ideogram **view** for editor operations (SAM
/// bbox computation, element/style recaption). Unlike [ideogramFromMoss]
/// this never drops bbox-less items — element indices stay aligned with the
/// MOSS `items` list, so per-index results (SAM boxes, recaptioned elements)
/// can be written back at the same position. Pixel bboxes become normalized
/// 0–1000 yxyx; missing bboxes stay null.
IdeogramCaption mossIdeogramView(MossLayoutCaption moss) {
  return IdeogramCaption(
    highLevelDescription: moss.summary.caption,
    styleDescription: IdeogramStyleDescription(
      aesthetics: moss.summary.meta.join(', '),
      lighting: '',
      medium: 'photograph',
      colorPalette: moss.summary.palette,
    ),
    compositionalDeconstruction: IdeogramCompositionalDeconstruction(
      background: '',
      elements: moss.items
          .map(
            (MossItem item) => IdeogramElement(
              type: item.label == 'text' ? 'text' : 'obj',
              bbox: item.bbox == null
                  ? null
                  : _pixelToNormalizedBbox(item.bbox!, moss.width, moss.height),
              desc: item.caption,
              text: item.label == 'text' ? (item.text ?? '') : null,
            ),
          )
          .toList(),
    ),
  );
}

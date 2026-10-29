import 'dart:convert';

import '../utils/compact_json.dart';
import 'moss_layout_caption.dart';

/// The two MOSS coordinate contracts, kept strictly apart.
///
/// - [draft]: stored editable layout. Top-left-origin absolute pixel
///   `xyxy` boxes against the declared canvas (`width`/`height` present and
///   positive). Markers, when present, are `bbox_coord_space: abs` and
///   `bbox_format: xyxy`.
/// - [native]: compiled trainer/model prompt. Canvas-center-origin integer
///   `yxyx` boxes; canvas metadata is absent by design. Markers, when present,
///   are `bbox_coord_space: abs_centralized` and `bbox_format: yxyx`.
enum MossCoordinateContract { draft, native }

/// Severity of a [MossFormatDiagnostic].
enum MossDiagnosticSeverity { info, warning, error }

/// Structured problem report for parsing/validating/converting a MOSS
/// caption. [code] values are stable identifiers (see [MossDiagnosticCodes]);
/// [suggestedAction] is a human-readable remedy.
class MossFormatDiagnostic {
  const MossFormatDiagnostic({
    required this.code,
    required this.severity,
    required this.message,
    this.imagePath,
    this.itemIndex,
    this.suggestedAction,
  });

  final MossDiagnosticCodes code;
  final MossDiagnosticSeverity severity;
  final String message;

  /// Path of the source image the caption belongs to, when known.
  final String? imagePath;

  /// Index into `items` the diagnostic is about, when item-scoped.
  final int? itemIndex;

  final String? suggestedAction;

  @override
  String toString() {
    final String at = itemIndex == null ? '' : ' (item $itemIndex)';
    final String action = suggestedAction == null ? '' : ' — $suggestedAction';
    return '${severity.name}: $message$at$action';
  }
}

/// Stable diagnostic identifiers. Never repurpose an existing code; add new
/// ones so consumers can switch on them.
enum MossDiagnosticCodes {
  /// JSON is not decodable or lacks the summary/items shape.
  notMossJson,

  /// The JSON carries native centered markers (`abs_centralized`/`yxyx`) but
  /// was opened through the draft path.
  nativeMarkersInDraftPath,

  /// The JSON carries draft markers (`abs`/`xyxy`) but was opened through the
  /// native path.
  draftMarkersInNativePath,

  /// Markers exist but their combination is not one of the two contracts.
  unsupportedMarkers,

  /// A field has the wrong JSON type (summary not an object, tags not a
  /// string list, bbox fractional, …) and was not coerced.
  malformedField,

  /// Draft canvas `width`/`height` missing, non-positive, or non-integer.
  missingCanvasSize,

  /// A native prompt was parsed without a known canvas (associated image or
  /// explicit user input). No 1024 default is applied.
  nativeCanvasUnknown,

  /// A bbox is missing, not four numbers, non-finite, or non-integer.
  invalidBboxShape,

  /// Box corners are reversed (x1 >= x2 or y1 >= y2).
  reversedBbox,

  /// Box coordinates fall outside the declared canvas.
  bboxOutOfBounds,

  /// Zero-area box (degenerate after parsing).
  zeroAreaBbox,

  /// An item is missing its caption text.
  missingCaption,

  /// A `text`-labelled item has no `text` payload.
  missingTextPayload,

  /// Conversion dropped the item (e.g. no bbox for MOSS output).
  itemDropped,

  /// A lossy content mapping occurred (e.g. Ideogram background folded into
  /// the MOSS summary).
  lossyContentMapping,

  /// Source image dimensions could not be established.
  imageDimensionsUnknown,

  /// The declared draft canvas disagrees with the source image dimensions.
  canvasImageMismatch,

  /// A destination caption already exists for the item (collision policy
  /// skipped it).
  destinationCollision,

  /// The source caption changed after the job was captured, so the result
  /// was not written.
  sourceChangedDuringConversion,

  /// Export/parse options are out of range.
  invalidOptions,
}

/// How strictly a caption is being interpreted. Legacy tolerance keeps old
/// stored drafts readable; strict gates (conversion, export) demand valid
/// geometry and explicit provenance.
enum MossValidationStrictness { legacyTolerant, strict }

/// Classification outcome that can express "unsupported markers" — explicit
/// but unrecognized marker combinations are never silently mapped onto a
/// known contract.
class MossJsonClassification {
  const MossJsonClassification.draft({required bool explicit})
    : this._(MossCoordinateContract.draft, explicit);
  const MossJsonClassification.native()
    : this._(MossCoordinateContract.native, true);
  const MossJsonClassification.unsupported() : this._(null, true);
  const MossJsonClassification._(this.contract, this.explicitMarkers);

  /// Null when markers are explicit but unrecognized — such input must be
  /// rejected, not interpreted.
  final MossCoordinateContract? contract;
  final bool explicitMarkers;
}

/// Classifies already-decoded MOSS JSON by its coordinate markers.
///
/// Absent markers are treated as legacy draft shape (draft, not explicit).
/// Explicit `abs_centralized`/`yxyx` markers mean native; explicit
/// `abs`/`xyxy` markers mean draft; any other explicit combination is
/// [MossJsonClassification.unsupported] and both parsers refuse it.
MossJsonClassification classifyMossJson(Map<String, dynamic> json) {
  final Object? coordSpace = json['bbox_coord_space'];
  final Object? bboxFormat = json['bbox_format'];
  if (coordSpace == null && bboxFormat == null) {
    return const MossJsonClassification.draft(explicit: false);
  }
  if (coordSpace is! String || bboxFormat is! String) {
    return const MossJsonClassification.unsupported();
  }
  if (coordSpace == 'abs_centralized' && bboxFormat == 'yxyx') {
    return const MossJsonClassification.native();
  }
  if (coordSpace == 'abs' && bboxFormat == 'xyxy') {
    return const MossJsonClassification.draft(explicit: true);
  }
  return const MossJsonClassification.unsupported();
}

/// True when [text] is MOSS JSON that follows the **draft** contract —
/// legacy drafts without markers included, but native prompts and unknown
/// marker combinations excluded. Cheap shape check for routers; use
/// [parseMossDraft] for real validation.
bool isDraftMossJson(String text) {
  final Map<String, dynamic>? json = _tryDecode(text);
  if (json == null) {
    return false;
  }
  return classifyMossJson(json).contract == MossCoordinateContract.draft;
}

/// Strict draft parse: requires a positive integer canvas, draft-shaped (or
/// absent) coordinate markers, and raw-valid field types. Malformed fields
/// (fractional bbox values, non-object summary, non-string tags) produce
/// diagnostics instead of being silently coerced or thrown.
({MossLayoutCaption? caption, List<MossFormatDiagnostic> diagnostics})
parseMossDraft(String text, {String? imagePath}) {
  final List<MossFormatDiagnostic> diagnostics = <MossFormatDiagnostic>[];
  final Map<String, dynamic>? json = _tryDecode(text);
  if (json == null) {
    return (
      caption: null,
      diagnostics: <MossFormatDiagnostic>[
        _diag(
          MossDiagnosticCodes.notMossJson,
          'Not decodable MOSS layout JSON',
          imagePath,
          null,
        ),
      ],
    );
  }
  final MossJsonClassification classification = classifyMossJson(json);
  if (classification.contract == null) {
    diagnostics.add(
      _diag(
        MossDiagnosticCodes.unsupportedMarkers,
        'Unsupported coordinate markers '
        '(bbox_coord_space: ${json['bbox_coord_space']}, '
        'bbox_format: ${json['bbox_format']}) — refusing to interpret',
        imagePath,
        null,
      ),
    );
    return (caption: null, diagnostics: diagnostics);
  }
  if (classification.contract == MossCoordinateContract.native) {
    diagnostics.add(
      _diag(
        MossDiagnosticCodes.nativeMarkersInDraftPath,
        'Native centered layout (abs_centralized/yxyx) cannot be opened as a '
        'top-left draft',
        imagePath,
        null,
      ),
    );
    return (caption: null, diagnostics: diagnostics);
  }

  final int? width = _positiveInt(json['width']);
  final int? height = _positiveInt(json['height']);
  if (width == null || height == null) {
    diagnostics.add(
      _diag(
        MossDiagnosticCodes.missingCanvasSize,
        'Draft canvas width/height missing or invalid '
        '(width: ${json['width']}, height: ${json['height']})',
        imagePath,
        null,
        suggestedAction:
            'Supply the real source image dimensions before converting.',
      ),
    );
    return (caption: null, diagnostics: diagnostics);
  }

  diagnostics.addAll(_validateRawDraftFields(json, imagePath: imagePath));
  // Raw fields are validated, so coercion via fromJson cannot throw on the
  // checked paths and cannot truncate anything we accepted.
  final MossLayoutCaption draft = MossLayoutCaption.fromJson(json);
  diagnostics.addAll(validateMossDraftGeometry(draft, imagePath: imagePath));
  final bool fatal = diagnostics.any(
    (MossFormatDiagnostic d) => d.severity == MossDiagnosticSeverity.error,
  );
  return (caption: fatal ? null : draft, diagnostics: diagnostics);
}

/// Strict native parse: requires recognized native markers, a positive
/// caller-supplied canvas (from the associated image or explicit user input —
/// never a default), and raw-valid field types. Centered `yxyx` boxes are
/// converted to top-left `xyxy` pixels against [canvasWidth]×[canvasHeight].
({MossLayoutCaption? caption, List<MossFormatDiagnostic> diagnostics})
parseMossNative(
  String text, {
  required int canvasWidth,
  required int canvasHeight,
  String? imagePath,
}) {
  final List<MossFormatDiagnostic> diagnostics = <MossFormatDiagnostic>[];
  if (canvasWidth <= 0 || canvasHeight <= 0) {
    return (
      caption: null,
      diagnostics: <MossFormatDiagnostic>[
        _diag(
          MossDiagnosticCodes.nativeCanvasUnknown,
          'canvas dimensions must be positive, got ${canvasWidth}x'
          '$canvasHeight',
          imagePath,
          null,
        ),
      ],
    );
  }
  final Map<String, dynamic>? json = _tryDecode(text);
  if (json == null) {
    return (
      caption: null,
      diagnostics: <MossFormatDiagnostic>[
        _diag(
          MossDiagnosticCodes.notMossJson,
          'Not decodable MOSS layout JSON',
          imagePath,
          null,
        ),
      ],
    );
  }
  final MossJsonClassification classification = classifyMossJson(json);
  if (classification.contract != MossCoordinateContract.native) {
    diagnostics.add(
      _diag(
        classification.contract == MossCoordinateContract.draft
            ? MossDiagnosticCodes.draftMarkersInNativePath
            : MossDiagnosticCodes.unsupportedMarkers,
        classification.contract == MossCoordinateContract.draft
            ? 'Not a native centered layout (abs_centralized/yxyx markers '
                  'required)'
            : 'Unsupported coordinate markers '
                  '(bbox_coord_space: ${json['bbox_coord_space']}, '
                  'bbox_format: ${json['bbox_format']})',
        imagePath,
        null,
        suggestedAction: classification.contract == MossCoordinateContract.draft
            ? 'Open top-left drafts through the draft parser instead.'
            : null,
      ),
    );
    return (caption: null, diagnostics: diagnostics);
  }

  final Object? rawSummary = json['summary'];
  if (rawSummary != null && rawSummary is! Map<String, dynamic>) {
    diagnostics.add(
      _diag(
        MossDiagnosticCodes.malformedField,
        'summary must be an object, got ${rawSummary.runtimeType}',
        imagePath,
        null,
      ),
    );
  }
  final Object? rawItems = json['items'];
  if (rawItems is! List<dynamic>) {
    return (
      caption: null,
      diagnostics: <MossFormatDiagnostic>[
        _diag(
          MossDiagnosticCodes.notMossJson,
          'Native layout has no items array',
          imagePath,
          null,
        ),
      ],
    );
  }

  final int halfWidth = canvasWidth ~/ 2;
  final int halfHeight = canvasHeight ~/ 2;
  final List<MossItem> items = <MossItem>[];
  for (int i = 0; i < rawItems.length; i++) {
    final Object? raw = rawItems[i];
    if (raw is! Map<String, dynamic>) {
      diagnostics.add(_badItem(i, imagePath, 'item is not an object'));
      continue;
    }
    for (final String key in const <String>['tags', 'palette']) {
      final Object? v = raw[key];
      if (v != null &&
          !(v is List<dynamic> && v.every((Object? e) => e is String))) {
        diagnostics.add(
          _itemDiag(
            MossDiagnosticCodes.malformedField,
            '$key must be a list of strings',
            imagePath,
            i,
          ),
        );
      }
    }
    final List<int>? centered = _intList(raw['bbox']);
    if (centered == null || centered.length != 4) {
      diagnostics.add(
        _itemDiag(
          MossDiagnosticCodes.invalidBboxShape,
          'bbox must be four integers, got ${raw['bbox']}',
          imagePath,
          i,
        ),
      );
      continue;
    }
    // Native order is yxyx centered; convert to top-left xyxy.
    final int y1 = centered[0] + halfHeight;
    final int x1 = centered[1] + halfWidth;
    final int y2 = centered[2] + halfHeight;
    final int x2 = centered[3] + halfWidth;
    if (x1 < 0 || y1 < 0 || x2 > canvasWidth || y2 > canvasHeight) {
      diagnostics.add(
        _itemDiag(
          MossDiagnosticCodes.bboxOutOfBounds,
          'centered box $centered falls outside the ${canvasWidth}x'
          '$canvasHeight canvas',
          imagePath,
          i,
        ),
      );
      continue;
    }
    if (x1 >= x2 || y1 >= y2) {
      diagnostics.add(
        _itemDiag(
          MossDiagnosticCodes.zeroAreaBbox,
          'box collapses to zero area: $centered',
          imagePath,
          i,
        ),
      );
      continue;
    }
    final Object? rawTags = raw['tags'];
    final Object? rawPalette = raw['palette'];
    items.add(
      MossItem(
        label: raw['label'] as String? ?? 'object',
        caption: raw['caption'] as String? ?? '',
        text: raw['text'] as String?,
        bbox: <int>[x1, y1, x2, y2],
        tags: rawTags is List<dynamic>
            ? rawTags.cast<String>().toList()
            : const <String>[],
        palette: rawPalette is List<dynamic>
            ? rawPalette.cast<String>().toList()
            : const <String>[],
      ),
    );
  }

  final bool fatal = diagnostics.any(
    (MossFormatDiagnostic d) => d.severity == MossDiagnosticSeverity.error,
  );
  final MossLayoutCaption caption = MossLayoutCaption(
    width: canvasWidth,
    height: canvasHeight,
    summary: MossSummary.fromJson(
      json['summary'] as Map<String, dynamic>? ?? <String, dynamic>{},
    ),
    items: items,
  );
  return (caption: fatal ? null : caption, diagnostics: diagnostics);
}

/// Validates raw draft field types BEFORE [MossLayoutCaption.fromJson]
/// coercion, so fractional bboxes / wrong-typed fields are reported instead
/// of truncated or thrown.
List<MossFormatDiagnostic> _validateRawDraftFields(
  Map<String, dynamic> json, {
  String? imagePath,
}) {
  final List<MossFormatDiagnostic> diagnostics = <MossFormatDiagnostic>[];
  final Object? rawSummary = json['summary'];
  if (rawSummary != null && rawSummary is! Map<String, dynamic>) {
    diagnostics.add(
      _diag(
        MossDiagnosticCodes.malformedField,
        'summary must be an object, got ${rawSummary.runtimeType}',
        imagePath,
        null,
      ),
    );
  }
  final Object? rawItems = json['items'];
  if (rawItems is! List<dynamic>) {
    diagnostics.add(
      _diag(
        MossDiagnosticCodes.notMossJson,
        'items must be an array',
        imagePath,
        null,
      ),
    );
    return diagnostics;
  }
  for (int i = 0; i < rawItems.length; i++) {
    final Object? raw = rawItems[i];
    if (raw is! Map<String, dynamic>) {
      diagnostics.add(_badItem(i, imagePath, 'item is not an object'));
      continue;
    }
    final List<int>? bbox = _intList(raw['bbox']);
    if (raw['bbox'] != null && bbox == null) {
      diagnostics.add(
        _itemDiag(
          MossDiagnosticCodes.invalidBboxShape,
          'bbox must be four integers, got ${raw['bbox']} (fractional '
          'coordinates are rejected, not truncated)',
          imagePath,
          i,
        ),
      );
    }
    for (final String key in const <String>['tags', 'palette']) {
      final Object? v = raw[key];
      if (v != null &&
          !(v is List<dynamic> && v.every((Object? e) => e is String))) {
        diagnostics.add(
          _itemDiag(
            MossDiagnosticCodes.malformedField,
            '$key must be a list of strings',
            imagePath,
            i,
          ),
        );
      }
    }
  }
  return diagnostics;
}

/// Validates draft geometry (top-left xyxy against the declared canvas).
/// Legacy-tolerant runs collect warnings; strict runs treat
/// out-of-bounds/reversed/zero-area boxes as fatal.
List<MossFormatDiagnostic> validateMossDraftGeometry(
  MossLayoutCaption draft, {
  String? imagePath,
  MossValidationStrictness strictness = MossValidationStrictness.strict,
}) {
  final MossDiagnosticSeverity geometrySeverity =
      strictness == MossValidationStrictness.strict
      ? MossDiagnosticSeverity.error
      : MossDiagnosticSeverity.warning;
  final List<MossFormatDiagnostic> diagnostics = <MossFormatDiagnostic>[];
  for (int i = 0; i < draft.items.length; i++) {
    final MossItem item = draft.items[i];
    if (item.caption.isEmpty) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.missingCaption,
          severity: MossDiagnosticSeverity.warning,
          message: 'item has an empty caption',
          imagePath: imagePath,
          itemIndex: i,
          suggestedAction: 'Add a description or remove the item.',
        ),
      );
    }
    if (item.label == 'text' && (item.text ?? '').isEmpty) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.missingTextPayload,
          severity: MossDiagnosticSeverity.warning,
          message: 'text item carries no text payload',
          imagePath: imagePath,
          itemIndex: i,
          suggestedAction: 'Set the exact visible characters.',
        ),
      );
    }
    final List<int>? bbox = item.bbox;
    if (bbox == null) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.invalidBboxShape,
          severity: geometrySeverity,
          message: 'item has no bbox',
          imagePath: imagePath,
          itemIndex: i,
          suggestedAction: 'Draw a box or remove the item.',
        ),
      );
      continue;
    }
    if (bbox.length != 4 || bbox.any((int v) => v < 0)) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.invalidBboxShape,
          severity: geometrySeverity,
          message: 'bbox must be four non-negative integers, got $bbox',
          imagePath: imagePath,
          itemIndex: i,
        ),
      );
      continue;
    }
    final int x1 = bbox[0];
    final int y1 = bbox[1];
    final int x2 = bbox[2];
    final int y2 = bbox[3];
    if (x1 >= x2 || y1 >= y2) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: x1 == x2 || y1 == y2
              ? MossDiagnosticCodes.zeroAreaBbox
              : MossDiagnosticCodes.reversedBbox,
          severity: geometrySeverity,
          message: 'box $bbox is reversed or degenerate',
          imagePath: imagePath,
          itemIndex: i,
        ),
      );
      continue;
    }
    if (x2 > draft.width || y2 > draft.height) {
      diagnostics.add(
        MossFormatDiagnostic(
          code: MossDiagnosticCodes.bboxOutOfBounds,
          severity: geometrySeverity,
          message:
              'box $bbox exceeds the ${draft.width}x${draft.height} canvas',
          imagePath: imagePath,
          itemIndex: i,
        ),
      );
    }
  }
  return diagnostics;
}

/// Serializes a draft (top-left xyxy pixels) into the native centered `yxyx`
/// prompt schema against the **final output** dimensions
/// ([outputWidth]×[outputHeight]).
///
/// The draft's declared canvas is only valid if it equals the output frame —
/// callers that resized/cropped the image must transform boxes first and
/// build a new [MossLayoutCaption] with the output dimensions. Boxes are
/// floored/ceiled around the canvas center exactly like
/// [MossLayoutCaption.toCompiledPromptString], but the result keeps the
/// explicit `bbox_coord_space: abs_centralized` / `bbox_format: yxyx`
/// markers from the official schema.
String toNativePromptString(
  MossLayoutCaption draft, {
  required int outputWidth,
  required int outputHeight,
}) {
  if (draft.width != outputWidth || draft.height != outputHeight) {
    throw StateError(
      'draft canvas ${draft.width}x${draft.height} does not match the output '
      'frame ${outputWidth}x$outputHeight; transform boxes to the output '
      'frame first',
    );
  }
  final List<MossFormatDiagnostic> problems = validateMossDraftGeometry(draft);
  final List<MossFormatDiagnostic> fatal = problems
      .where(
        (MossFormatDiagnostic d) => d.severity == MossDiagnosticSeverity.error,
      )
      .toList();
  if (fatal.isNotEmpty) {
    throw StateError('draft fails native serialization: ${fatal.first}');
  }
  final double halfWidth = outputWidth / 2;
  final double halfHeight = outputHeight / 2;
  final List<Map<String, dynamic>> compiledItems = draft.items.map((
    MossItem item,
  ) {
    final List<int> bbox = item.bbox!;
    final int x1 = bbox[0];
    final int y1 = bbox[1];
    final int x2 = bbox[2];
    final int y2 = bbox[3];
    return <String, dynamic>{
      'label': item.label,
      'caption': item.caption,
      if (item.label == 'text') 'text': item.text ?? '',
      'bbox': <int>[
        (y1 - halfHeight).floor(),
        (x1 - halfWidth).floor(),
        (y2 - halfHeight).ceil(),
        (x2 - halfWidth).ceil(),
      ],
      if (item.tags.isNotEmpty) 'tags': item.tags,
      if (item.palette.isNotEmpty) 'palette': item.palette,
    };
  }).toList();
  final Map<String, dynamic> compiled = <String, dynamic>{
    'bbox_coord_space': 'abs_centralized',
    'bbox_format': 'yxyx',
    'summary': draft.summary.toJson(),
    'items': compiledItems,
  };
  return compactJson(compiled);
}

// -- helpers ----------------------------------------------------------------

Map<String, dynamic>? _tryDecode(String text) {
  if (!text.trimLeft().startsWith('{')) {
    return null;
  }
  try {
    final Object? decoded = jsonDecode(text);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

int? _positiveInt(Object? value) {
  if (value is int && value > 0) {
    return value;
  }
  if (value is num && value > 0 && value == value.round()) {
    return value.toInt();
  }
  return null;
}

List<int>? _intList(Object? value) {
  if (value is! List<dynamic>) {
    return null;
  }
  final List<int> out = <int>[];
  for (final Object? e in value) {
    if (e is int) {
      out.add(e);
    } else if (e is num && e == e.round()) {
      out.add(e.toInt());
    } else {
      return null;
    }
  }
  return out;
}

MossFormatDiagnostic _diag(
  MossDiagnosticCodes code,
  String message,
  String? imagePath,
  int? itemIndex, {
  String? suggestedAction,
}) => MossFormatDiagnostic(
  code: code,
  severity: MossDiagnosticSeverity.error,
  message: message,
  imagePath: imagePath,
  itemIndex: itemIndex,
  suggestedAction: suggestedAction,
);

MossFormatDiagnostic _itemDiag(
  MossDiagnosticCodes code,
  String message,
  String? imagePath,
  int itemIndex,
) => MossFormatDiagnostic(
  code: code,
  severity: MossDiagnosticSeverity.error,
  message: message,
  imagePath: imagePath,
  itemIndex: itemIndex,
);

MossFormatDiagnostic _badItem(int index, String? imagePath, String why) =>
    _itemDiag(MossDiagnosticCodes.notMossJson, why, imagePath, index);

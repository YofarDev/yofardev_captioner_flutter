import 'dart:io';

import '../models/moss_conversion.dart';
import '../models/moss_format.dart';
import '../models/moss_layout_caption.dart';
import '../models/structured_caption_document.dart';
import 'image_dimension_resolver.dart';

/// The single implementation behind every Ideogram↔MOSS conversion entry
/// point (UI batch dialog, Agent API `/api/convert`, in-editor actions).
///
/// MOSS projection uses the **exact decoded source dimensions** (header fast
/// path, full-decode fallback, EXIF baked). When dimensions cannot be
/// established the conversion fails with an
/// [MossDiagnosticCodes.imageDimensionsUnknown] diagnostic — no 1024² frame
/// is ever invented.
class MossConversionService {
  MossConversionService({ImageDimensionLookup? dimensionLookup})
    : _dimensionLookup = dimensionLookup ?? defaultDimensionLookup;

  final ImageDimensionLookup _dimensionLookup;

  /// Converts [text] toward [target]. Returns `text: null` with diagnostics
  /// when the caption is not in the expected source format or geometry
  /// cannot be established.
  Future<MossConversionOutcome> convert({
    required String text,
    required CaptionFormat target,
    required File imageFile,
  }) async {
    if (text.trim().isEmpty) {
      return MossConversionOutcome.skip('no caption', imageFile.path);
    }
    final CaptionFormat source = detectCaptionFormat(text);
    if (source == CaptionFormat.plain) {
      return MossConversionOutcome.skip('plain caption', imageFile.path);
    }
    if (target == CaptionFormat.moss) {
      if (source != CaptionFormat.ideogram) {
        // MOSS source (or unparseable MOSS) toward moss: skip as already
        // target / refuse invalid input via strict parse below.
        final ({
          MossLayoutCaption? caption,
          List<MossFormatDiagnostic> diagnostics,
        })
        probed = parseMossDraft(text, imagePath: imageFile.path);
        final bool unsupported = probed.diagnostics.any(
          (MossFormatDiagnostic e) =>
              e.code == MossDiagnosticCodes.unsupportedMarkers ||
              e.code == MossDiagnosticCodes.nativeMarkersInDraftPath,
        );
        if (unsupported) {
          return MossConversionOutcome.failure(
            probed.diagnostics,
            imageFile.path,
          );
        }
        return MossConversionOutcome.skip('already MOSS', imageFile.path);
      }
      final ImageDimensions? dims = await _dimensionLookup(imageFile);
      if (dims == null) {
        return MossConversionOutcome.failure(<MossFormatDiagnostic>[
          MossFormatDiagnostic(
            code: MossDiagnosticCodes.imageDimensionsUnknown,
            severity: MossDiagnosticSeverity.error,
            message:
                'source image dimensions could not be read; refusing to '
                'invent a canvas',
            imagePath: imageFile.path,
            suggestedAction:
                'Check the image file, or convert manually with explicit '
                'dimensions.',
          ),
        ], imageFile.path);
      }
      final IdeogramDocument document =
          StructuredCaptionDocument.tryParse(text)! as IdeogramDocument;
      final MossFromIdeogramResult result = mossFromIdeogram(
        document.caption,
        width: dims.width,
        height: dims.height,
        imagePath: imageFile.path,
      );
      return MossConversionOutcome(
        text: result.caption.toJsonString(),
        convertedItems: result.caption.items.length,
        diagnostics: result.diagnostics,
        imagePath: imageFile.path,
      );
    }
    if (source != CaptionFormat.moss) {
      return MossConversionOutcome.skip('already Ideogram', imageFile.path);
    }
    // moss→ideogram goes through the STRICT draft parser: native prompts,
    // unknown marker combinations, missing canvases, and malformed fields
    // are refused with diagnostics — never coerced.
    final ({MossLayoutCaption? caption, List<MossFormatDiagnostic> diagnostics})
    strict = parseMossDraft(text, imagePath: imageFile.path);
    final MossLayoutCaption? draft = strict.caption;
    final List<MossFormatDiagnostic> parsed = strict.diagnostics;
    if (draft == null) {
      return MossConversionOutcome.failure(parsed, imageFile.path);
    }
    final List<MossFormatDiagnostic> diagnostics = parsed
        .map(
          (MossFormatDiagnostic d) => d.severity == MossDiagnosticSeverity.error
              ? MossFormatDiagnostic(
                  code: d.code,
                  severity: MossDiagnosticSeverity.warning,
                  message: d.message,
                  imagePath: d.imagePath,
                  itemIndex: d.itemIndex,
                  suggestedAction: d.suggestedAction,
                )
              // Legacy-tolerant: geometry warnings downgrade so readable
              // legacy drafts still convert; the warnings stay visible.
              : d,
        )
        .toList();
    final MossToIdeogramResult result = ideogramFromMoss(draft);
    return MossConversionOutcome(
      text: result.caption.toJsonString(),
      convertedItems:
          result.caption.compositionalDeconstruction.elements.length,
      diagnostics: diagnostics
        ..addAll(<MossFormatDiagnostic>[
          if (result.droppedItems > 0)
            MossFormatDiagnostic(
              code: MossDiagnosticCodes.itemDropped,
              severity: MossDiagnosticSeverity.warning,
              message:
                  '${result.droppedItems} bbox-less MOSS item(s) dropped '
                  '(Ideogram keeps them optional, but the geometry is '
                  'lost)',
              imagePath: imageFile.path,
            ),
        ]),
      imagePath: imageFile.path,
    );
  }
}

/// Outcome of converting one caption. Exactly one of [text]/[skipped]/
/// [failure] shapes applies: non-null [text] means success; [skipped] is a
/// benign reason nothing was produced; [failure] holds fatal diagnostics.
class MossConversionOutcome {
  const MossConversionOutcome({
    required this.text,
    required this.convertedItems,
    required this.diagnostics,
    required this.imagePath,
  }) : skippedReason = null,
       fatal = false;

  const MossConversionOutcome.skip(this.skippedReason, this.imagePath)
    : text = null,
      convertedItems = 0,
      diagnostics = const <MossFormatDiagnostic>[],
      fatal = false;

  const MossConversionOutcome.failure(this.diagnostics, this.imagePath)
    : text = null,
      convertedItems = 0,
      skippedReason = null,
      fatal = true;

  /// Converted storage JSON, when conversion succeeded.
  final String? text;

  /// Benign reason nothing was produced (empty, wrong format, already
  /// target format). Null on success and failure.
  final String? skippedReason;

  /// Number of items/elements in the converted result.
  final int convertedItems;

  /// Warnings and loss reports for a successful conversion; fatal
  /// diagnostics when [fatal].
  final List<MossFormatDiagnostic> diagnostics;

  final String imagePath;

  /// True when conversion failed hard (unreadable image, invalid input).
  final bool fatal;

  bool get success => text != null;
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

import '../../../../core/models/ideogram_caption.dart';
import '../../domain/models/multi_stage_quality_report.dart';
import '../models/vlm_analysis.dart';
import 'sam_process_service.dart';

/// Renders and writes the `debug/` artifacts (prompt, raw responses,
/// annotated bbox overlays, quality report) for structured runs in debug
/// mode. Purely diagnostic — the pipeline result never depends on it.
class StructuredDebugArtifactsWriter {
  const StructuredDebugArtifactsWriter();

  static final Logger _logger = Logger('StructuredDebugArtifactsWriter');

  /// Saves multi-stage-specific debug artifacts alongside the image in a
  /// `debug/` subfolder.
  Future<void> saveMultiStage({
    required File imageFile,
    required String enumeratePrompt,
    required String enumerateRawResponse,
    required MultiStageQualityReport qualityReport,
    required List<int> enrichFailures,
    required VlmAnalysis preEnrichAnalysis,
  }) async {
    final String stem = imageFile.path.replaceAll(RegExp(r'\.[^.]+$'), '');
    final Directory debugDir = Directory('${imageFile.parent.path}/debug');
    await debugDir.create(recursive: true);

    // Pre-enrich parsed VlmAnalysis.
    await File(
      '${debugDir.path}/${stem.split('/').last}_enumerate_analysis.json',
    ).writeAsString(
      const JsonEncoder.withIndent('  ').convert(preEnrichAnalysis.toJson()),
    );

    // Quality report.
    await File(
      '${debugDir.path}/${stem.split('/').last}_quality_report.txt',
    ).writeAsString(qualityReport.toFormattedString());
  }

  /// Saves debug artifacts alongside the image in a `debug/` subfolder.
  Future<void> save({
    required File imageFile,
    required String prompt,
    required String vlmRawResponse,
    required List<VlmObject> vlmObjects,
    required List<SamDetection> detections,
    required IdeogramCaption caption,
  }) async {
    final String stem = imageFile.path.replaceAll(RegExp(r'\.[^.]+$'), '');
    final Directory debugDir = Directory('${imageFile.parent.path}/debug');
    await debugDir.create(recursive: true);

    // 1. Prompt.
    await File(
      '${debugDir.path}/${stem.split('/').last}_prompt.txt',
    ).writeAsString(prompt);

    // 2. Raw VLM response.
    await File(
      '${debugDir.path}/${stem.split('/').last}_vlm_response.json',
    ).writeAsString(vlmRawResponse);

    // 3. Bbox overlay images (VLM and SAM separate) + selection log.
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? source = img.decodeImage(bytes);
      if (source != null) {
        final int imgW = source.width;
        final int imgH = source.height;

        // Build per-object selection log.
        final StringBuffer selectionLog = StringBuffer();
        selectionLog.writeln('bbox_selection_log');
        selectionLog.writeln('==================');
        final List<String> selectionLines = <String>[];
        for (int i = 0; i < vlmObjects.length; i++) {
          final VlmObject obj = vlmObjects[i];
          final List<int>? vlmBbox = obj.bbox;
          final SamDetection? matched = i < detections.length
              ? detections[i]
              : null;
          final bool samImproved =
              matched != null && !_bboxesEqual(matched.bbox, vlmBbox);
          final String chosen = samImproved ? 'SAM' : 'VLM';
          selectionLines.add(
            '${i + 1}. ${obj.name}: $chosen '
            '(VLM: ${_fmtBbox(vlmBbox)} | SAM: ${_fmtBbox(matched?.bbox)})',
          );
        }
        for (final String line in selectionLines) {
          selectionLog.writeln(line);
        }
        await File(
          '${debugDir.path}/${stem.split('/').last}_bbox_selection.txt',
        ).writeAsString(selectionLog.toString());

        // VLM-only overlay. Photo is faded 50% over white so the colored
        // bboxes pop. Each object gets a distinct palette color and the same
        // color is reused in the SAM image for cross-reference.
        final img.Image vlmImage = _fadeOnWhite(source, imgW, imgH);
        for (int i = 0; i < vlmObjects.length; i++) {
          final VlmObject obj = vlmObjects[i];
          if (obj.bbox == null) continue;
          final img.Color color = _bboxColor(i);
          _drawBboxOutline(vlmImage, obj.bbox!, color, imgW, imgH);
          _drawLabel(vlmImage, obj.name, obj.bbox!, imgW, imgH, color: color);
        }
        await File(
          '${debugDir.path}/${stem.split('/').last}_vlm_bboxes.png',
        ).writeAsBytes(img.encodePng(vlmImage));

        // SAM-only overlay (only genuine SAM refinements), faded 50% on
        // white. Color matches the same object's color in the VLM image.
        final img.Image samImage = _fadeOnWhite(source, imgW, imgH);
        for (int i = 0; i < detections.length; i++) {
          final SamDetection det = detections[i];
          if (det.bbox == null) continue;
          final List<int>? vlmBbox = i < vlmObjects.length
              ? vlmObjects[i].bbox
              : null;
          if (vlmBbox != null && _bboxesEqual(det.bbox, vlmBbox)) continue;
          final img.Color color = _bboxColor(i);
          _drawBboxOutline(samImage, det.bbox!, color, imgW, imgH);
          _drawLabel(
            samImage,
            '${det.name} (SAM)',
            det.bbox!,
            imgW,
            imgH,
            color: color,
          );
        }
        await File(
          '${debugDir.path}/${stem.split('/').last}_sam_bboxes.png',
        ).writeAsBytes(img.encodePng(samImage));
      }
    } catch (e) {
      _logger.warning('Failed to save bbox debug images: $e');
    }

    // 4. Final caption JSON.
    await File(
      '${debugDir.path}/${stem.split('/').last}_final_caption.json',
    ).writeAsString(caption.toJsonString());
  }

  /// High-contrast palette of distinguishable colors used to color-code
  /// bboxes per object so overlapping boxes stay readable.
  static final List<img.ColorRgb8> _bboxPalette = <img.ColorRgb8>[
    img.ColorRgb8(255, 64, 64), // red
    img.ColorRgb8(64, 200, 255), // cyan
    img.ColorRgb8(255, 220, 0), // yellow
    img.ColorRgb8(180, 80, 255), // purple
    img.ColorRgb8(0, 220, 120), // green
    img.ColorRgb8(255, 140, 0), // orange
    img.ColorRgb8(255, 0, 200), // magenta
    img.ColorRgb8(0, 160, 255), // blue
    img.ColorRgb8(150, 255, 0), // lime
    img.ColorRgb8(255, 100, 160), // pink
  ];

  /// Returns a palette color for the object at [index], cycling when there
  /// are more objects than palette entries.
  img.Color _bboxColor(int index) => _bboxPalette[index % _bboxPalette.length];

  /// Returns a copy of [source] composited at 50% opacity over a solid white
  /// background, so overlaid colored bboxes stand out.
  img.Image _fadeOnWhite(img.Image source, int imgW, int imgH) {
    final img.Image base = img.Image(width: imgW, height: imgH);
    img.fill(base, color: img.ColorRgb8(255, 255, 255));
    // Composite the photo at half alpha: clone then halve the alpha channel.
    final img.Image faded = source.clone();
    for (final img.Pixel p in faded) {
      p.a = (p.a * 0.5).round().clamp(0, 255);
    }
    img.compositeImage(base, faded);
    return base;
  }

  /// Draws a colored bbox outline on [image] using [y1, x1, y2, x2]
  /// normalized 0-1000 coordinates.
  void _drawBboxOutline(
    img.Image image,
    List<int> bbox,
    img.Color color,
    int imgW,
    int imgH,
  ) {
    final int y1 = (bbox[0] / 1000 * imgH).round().clamp(0, imgH - 1);
    final int x1 = (bbox[1] / 1000 * imgW).round().clamp(0, imgW - 1);
    final int y2 = (bbox[2] / 1000 * imgH).round().clamp(y1 + 1, imgH);
    final int x2 = (bbox[3] / 1000 * imgW).round().clamp(x1 + 1, imgW);
    img.drawRect(
      image,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: color,
      thickness: 3,
    );
  }

  /// Draws the [label] text at the top-left corner of [bbox]. The text is
  /// drawn in [color] (defaulting to white) with a black drop shadow for
  /// readability against any background.
  void _drawLabel(
    img.Image image,
    String label,
    List<int> bbox,
    int imgW,
    int imgH, {
    img.Color? color,
  }) {
    final int y1 = (bbox[0] / 1000 * imgH).round().clamp(0, imgH - 1);
    final int x1 = (bbox[1] / 1000 * imgW).round().clamp(0, imgW - 1);
    final int labelX = (x1 + 2).clamp(0, imgW - 1);
    final int labelY = (y1 + 2).clamp(0, (imgH - 14).clamp(0, imgH));
    final img.Color text = color ?? img.ColorRgb8(255, 255, 255);
    // Drop shadow for readability.
    img.drawString(
      image,
      label,
      font: img.arial14,
      x: labelX + 1,
      y: labelY + 1,
      color: img.ColorRgb8(0, 0, 0),
    );
    img.drawString(
      image,
      label,
      font: img.arial14,
      x: labelX,
      y: labelY,
      color: text,
    );
  }

  /// Returns true if two [y1, x1, y2, x2] bboxes are identical.
  bool _bboxesEqual(List<int>? a, List<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Formats a [y1, x1, y2, x2] bbox as a readable string. (Copied from the
  /// repository, which keeps its own for prompt building.)
  String _fmtBbox(List<int>? bbox) {
    if (bbox == null) return 'none';
    return '[${bbox[0]}, ${bbox[1]}, ${bbox[2]}, ${bbox[3]}]';
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

import '../../../../core/config/service_locator.dart';
import '../../../captioning/data/services/caption_service.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/data/models/structured_batch_overrides.dart';
import '../models/ideogram_caption.dart';
import '../models/vlm_analysis.dart';
import '../services/color_extraction_service.dart';
import '../services/sam_process_service.dart';
import '../services/structured_prompt_loader.dart';

/// Orchestrates the structured captioning pipeline:
/// global palette → VLM analysis → SAM detection → bbox matching → element
/// palettes → build Ideogram4 JSON.
class StructuredCaptionRepository {
  final Logger _logger = locator<Logger>();
  final CaptionService _captionService;
  final SamProcessService _samProcessService;
  final ColorExtractionService _colorExtractionService;
  final StructuredPromptLoader _promptLoader;

  StructuredCaptionRepository({
    CaptionService? captionService,
    SamProcessService? samProcessService,
    ColorExtractionService? colorExtractionService,
    StructuredPromptLoader? promptLoader,
  }) : _captionService = captionService ?? CaptionService(),
       _samProcessService = samProcessService ?? SamProcessService(),
       _colorExtractionService =
           colorExtractionService ?? ColorExtractionService(),
       _promptLoader = promptLoader ?? StructuredPromptLoader();

  /// Runs the full pipeline on a single image.
  ///
  /// [onProgress] emits step descriptions for UI progress tracking.
  /// [debugMode] saves prompt, raw VLM response, bbox overlay and final
  /// caption alongside the image in a debug/ subfolder.
  Future<IdeogramCaption> generateStructuredCaption(
    LlmConfig config,
    File imageFile, {
    required void Function(String step) onProgress,
    StructuredBatchOverrides? overrides,
    bool debugMode = false,
  }) async {
    // Step 1: Global color palette.
    onProgress('Extracting color palette...');
    List<String> globalPalette = <String>[];
    try {
      globalPalette = await _colorExtractionService.extractPalette(imageFile);
    } catch (e) {
      _logger.warning('Global palette extraction failed: $e');
    }

    // Step 2: VLM analysis.
    onProgress('Analyzing image with VLM...');
    final String prompt = await _promptLoader.loadVisionAnalysisPrompt();
    final String vlmRawResponse = await _captionService.getCaption(
      config,
      imageFile,
      prompt,
    );
    final VlmAnalysis analysis = _parseVlmResponse(vlmRawResponse);
    _logger.info('VLM analysis parsed: ${analysis.objects.length} objects');

    // Step 3: SAM3 detection.
    onProgress(
      'Running SAM detection for ${analysis.objects.length} objects...',
    );
    final List<String> objectNames = analysis.objects
        .map((VlmObject o) => o.name)
        .toList();
    final List<VlmObjectBboxPair> vlmBboxes = analysis.objects
        .map((VlmObject o) => VlmObjectBboxPair(name: o.name, bbox: o.bbox))
        .toList();

    List<SamDetection> detections = <SamDetection>[];
    try {
      detections = await _samProcessService.detectObjects(
        imageFile.path,
        objectNames,
      );
    } catch (e) {
      _logger.warning('SAM detection failed, using VLM bboxes: $e');
    }

    // Step 4: Greedy bbox matching.
    final List<SamDetection> matched = _matchDetectionsToObjects(
      detections,
      vlmBboxes,
    );

    // Step 5: Per-element color palettes.
    onProgress('Extracting element palettes...');
    final Map<String, List<String>> elementPalettes = <String, List<String>>{};
    for (int i = 0; i < analysis.objects.length; i++) {
      final List<int>? bbox = i < matched.length
          ? matched[i].bbox
          : analysis.objects[i].bbox;
      if (bbox != null) {
        try {
          final List<String> palette = await _colorExtractionService
              .extractPaletteFromRegion(imageFile, bbox);
          if (palette.isNotEmpty) {
            elementPalettes[analysis.objects[i].name] = palette;
          }
        } catch (e) {
          _logger.warning(
            'Element palette extraction failed for "${analysis.objects[i].name}": $e',
          );
        }
      }
    }

    // Step 6: Build final Ideogram4 JSON.
    onProgress('Building structured caption...');
    final IdeogramCaption caption = _buildIdeogramCaption(
      globalPalette,
      analysis,
      matched,
      elementPalettes,
      overrides,
    );

    // Debug artifacts.
    if (debugMode) {
      onProgress('Saving debug artifacts...');
      await _saveDebugArtifacts(
        imageFile: imageFile,
        prompt: prompt,
        vlmRawResponse: vlmRawResponse,
        vlmObjects: analysis.objects,
        detections: matched,
        caption: caption,
      );
    }

    return caption;
  }

  /// Saves debug artifacts alongside the image in a `debug/` subfolder.
  Future<void> _saveDebugArtifacts({
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

        // VLM-only overlay.
        final img.Image vlmImage = source.clone();
        for (final VlmObject obj in vlmObjects) {
          if (obj.bbox == null) continue;
          _drawBboxOutline(
            vlmImage,
            obj.bbox!,
            img.ColorRgb8(100, 150, 255),
            imgW,
            imgH,
          );
          _drawLabel(vlmImage, obj.name, obj.bbox!, imgW, imgH);
        }
        await File(
          '${debugDir.path}/${stem.split('/').last}_vlm_bboxes.png',
        ).writeAsBytes(img.encodePng(vlmImage));

        // SAM-only overlay (only genuine SAM refinements).
        final img.Image samImage = source.clone();
        for (int i = 0; i < detections.length; i++) {
          final SamDetection det = detections[i];
          if (det.bbox == null) continue;
          final List<int>? vlmBbox = i < vlmObjects.length
              ? vlmObjects[i].bbox
              : null;
          if (vlmBbox != null && _bboxesEqual(det.bbox, vlmBbox)) continue;
          _drawBboxOutline(
            samImage,
            det.bbox!,
            img.ColorRgb8(100, 255, 100),
            imgW,
            imgH,
          );
          _drawLabel(samImage, '${det.name} (SAM)', det.bbox!, imgW, imgH);
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
    img.drawRect(image, x1: x1, y1: y1, x2: x2, y2: y2, color: color);
  }

  /// Draws the [label] text at the top-left corner of [bbox] with a
  /// black shadow for readability.
  void _drawLabel(
    img.Image image,
    String label,
    List<int> bbox,
    int imgW,
    int imgH,
  ) {
    final int y1 = (bbox[0] / 1000 * imgH).round().clamp(0, imgH - 1);
    final int x1 = (bbox[1] / 1000 * imgW).round().clamp(0, imgW - 1);
    final int labelX = (x1 + 2).clamp(0, imgW - 1);
    final int labelY = (y1 + 2).clamp(0, (imgH - 14).clamp(0, imgH));
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
      color: img.ColorRgb8(255, 255, 255),
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

  /// Formats a [y1, x1, y2, x2] bbox as a readable string.
  String _fmtBbox(List<int>? bbox) {
    if (bbox == null) return 'none';
    return '[${bbox[0]}, ${bbox[1]}, ${bbox[2]}, ${bbox[3]}]';
  }

  /// Parses the VLM response string into a [VlmAnalysis].
  ///
  /// Strips markdown code fences and handles common JSON formatting issues.
  /// Makes 2 attempts — on first failure, tries a simplified prompt.
  VlmAnalysis _parseVlmResponse(String raw) {
    final String cleaned = _stripMarkdownFences(raw);

    try {
      final Map<String, dynamic> json =
          jsonDecode(cleaned) as Map<String, dynamic>;
      return _parseAnalysisJson(json);
    } catch (e) {
      _logger.warning('Failed to parse VLM response: $e');
      _logger.fine('Raw response was: $raw');
      throw FormatException('Failed to parse VLM JSON response: $e');
    }
  }

  String _stripMarkdownFences(String input) {
    String s = input.trim();
    // Remove ```json ... ``` wrapper.
    if (s.startsWith('```')) {
      final int firstNewline = s.indexOf('\n');
      if (firstNewline >= 0) {
        s = s.substring(firstNewline + 1);
      }
      if (s.endsWith('```')) {
        s = s.substring(0, s.length - 3);
      }
      s = s.trim();
    }
    return s;
  }

  VlmAnalysis _parseAnalysisJson(Map<String, dynamic> json) {
    // Parse style.
    final Map<String, dynamic> styleJson =
        json['style'] as Map<String, dynamic>;
    final VlmStyle style = VlmStyle(
      medium: styleJson['medium'] as String? ?? 'photograph',
      aesthetics: styleJson['aesthetics'] as String? ?? '',
      lighting: styleJson['lighting'] as String? ?? '',
      photoOrArt: styleJson['photo_or_art'] as String? ?? '',
    );

    // Parse objects — normalize bbox format to [y1, x1, y2, x2].
    final List<dynamic> objectsJson =
        json['objects'] as List<dynamic>? ?? <dynamic>[];
    final List<VlmObject> objects = objectsJson.map((dynamic o) {
      final Map<String, dynamic> obj = o as Map<String, dynamic>;
      List<int>? bbox;
      final dynamic rawBbox = obj['bbox'];
      if (rawBbox is List && rawBbox.length == 4) {
        // VLMs return [x1, y1, x2, y2] regardless of prompt instructions.
        // Swap to Ideogram [y1, x1, y2, x2] format.
        final List<int> raw = rawBbox
            .map((dynamic v) => (v as num).round())
            .toList();
        bbox = <int>[raw[1], raw[0], raw[3], raw[2]];
      }
      return VlmObject(
        name: obj['name'] as String? ?? '',
        desc: obj['desc'] as String? ?? '',
        hasText: obj['has_text'] as bool? ?? false,
        visibleText: obj['visible_text'] as String?,
        bbox: bbox,
      );
    }).toList();

    return VlmAnalysis(
      highLevelDescription: json['high_level_description'] as String? ?? '',
      style: style,
      background: json['background'] as String? ?? '',
      objects: objects,
    );
  }

  /// Greedy bbox matching between SAM detections and VLM objects.
  ///
  /// Ported from reference repo's sam_detection.py matching logic.
  /// Groups by name, matches by center distance, falls back to VLM bbox.
  List<SamDetection> _matchDetectionsToObjects(
    List<SamDetection> detections,
    List<VlmObjectBboxPair> vlmObjects,
  ) {
    final int n = vlmObjects.length;
    final List<SamDetection?> results = List<SamDetection?>.filled(n, null);

    if (detections.isEmpty) {
      // No SAM detections — fall back to VLM bboxes.
      return vlmObjects
          .map(
            (VlmObjectBboxPair o) => SamDetection(name: o.name, bbox: o.bbox),
          )
          .toList();
    }

    // Group VLM object indices by name.
    final Map<String, List<int>> nameToIndices = <String, List<int>>{};
    for (int i = 0; i < n; i++) {
      final String name = vlmObjects[i].name;
      nameToIndices.putIfAbsent(name, () => <int>[]).add(i);
    }

    // Group SAM detections by name.
    final Map<String, List<SamDetection>> nameToDetections =
        <String, List<SamDetection>>{};
    for (final SamDetection det in detections) {
      nameToDetections.putIfAbsent(det.name, () => <SamDetection>[]).add(det);
    }

    // For each unique name, greedily match SAM detections to VLM objects.
    for (final MapEntry<String, List<int>> entry in nameToIndices.entries) {
      final String name = entry.key;
      final List<int> vlmIndices = entry.value;
      final List<SamDetection> samDets =
          nameToDetections[name] ?? <SamDetection>[];

      if (samDets.isEmpty) continue;

      if (samDets.length == 1 && vlmIndices.length > 1) {
        // One SAM box, multiple VLM objects — assign to closest.
        final Point<double>? samCenter = _center(samDets[0].bbox);
        int bestIdx = 0;
        double bestDist = double.infinity;
        for (int vi = 0; vi < vlmIndices.length; vi++) {
          final Point<double>? vlmCenter = _center(
            vlmObjects[vlmIndices[vi]].bbox,
          );
          final double d = _distance(vlmCenter, samCenter);
          if (d < bestDist) {
            bestDist = d;
            bestIdx = vi;
          }
        }
        results[vlmIndices[bestIdx]] = samDets[0];
      } else {
        // Greedy matching by ascending center distance.
        final List<_MatchPair> pairs = <_MatchPair>[];
        for (int si = 0; si < samDets.length; si++) {
          final Point<double>? samCenter = _center(samDets[si].bbox);
          for (int vi = 0; vi < vlmIndices.length; vi++) {
            final Point<double>? vlmCenter = _center(
              vlmObjects[vlmIndices[vi]].bbox,
            );
            pairs.add(
              _MatchPair(
                dist: _distance(vlmCenter, samCenter),
                samIdx: si,
                vlmIdx: vi,
              ),
            );
          }
        }
        pairs.sort((_MatchPair a, _MatchPair b) => a.dist.compareTo(b.dist));

        final Set<int> usedSam = <int>{};
        final Set<int> usedVlm = <int>{};
        for (final _MatchPair pair in pairs) {
          if (usedSam.contains(pair.samIdx) || usedVlm.contains(pair.vlmIdx)) {
            continue;
          }
          results[vlmIndices[pair.vlmIdx]] = samDets[pair.samIdx];
          usedSam.add(pair.samIdx);
          usedVlm.add(pair.vlmIdx);
        }
      }
    }

    // Fill unmatched slots with VLM bbox fallback.
    for (int i = 0; i < n; i++) {
      results[i] ??= SamDetection(
        name: vlmObjects[i].name,
        bbox: vlmObjects[i].bbox,
      );
    }

    return results.cast<SamDetection>();
  }

  /// Builds the final [IdeogramCaption] from pipeline data.
  IdeogramCaption _buildIdeogramCaption(
    List<String> globalPalette,
    VlmAnalysis analysis,
    List<SamDetection> detections,
    Map<String, List<String>> elementPalettes,
    StructuredBatchOverrides? overrides,
  ) {
    // Apply batch overrides if enabled.
    final String effectiveMedium =
        overrides != null &&
            overrides.enabled &&
            overrides.overrideMedium &&
            overrides.medium != null
        ? overrides.medium!
        : analysis.style.medium;

    final String effectiveAesthetics =
        overrides != null &&
            overrides.enabled &&
            overrides.overrideAesthetics &&
            overrides.aesthetics != null
        ? overrides.aesthetics!
        : analysis.style.aesthetics;

    final String effectiveLighting =
        overrides != null &&
            overrides.enabled &&
            overrides.overrideLighting &&
            overrides.lighting != null
        ? overrides.lighting!
        : analysis.style.lighting;

    final bool isPhoto = effectiveMedium == 'photograph';
    final String? effectiveStyleDetail =
        overrides != null &&
            overrides.enabled &&
            overrides.styleMode != null &&
            overrides.styleDetail != null
        ? overrides.styleDetail
        : null;

    final String effectiveBackground =
        overrides != null &&
            overrides.enabled &&
            overrides.overrideBackground &&
            overrides.background != null
        ? overrides.background!
        : analysis.background;

    final IdeogramStyleDescription styleDescription = IdeogramStyleDescription(
      aesthetics: effectiveAesthetics,
      lighting: effectiveLighting,
      medium: effectiveMedium,
      photo:
          overrides != null &&
              overrides.enabled &&
              overrides.styleMode == 'photo' &&
              effectiveStyleDetail != null
          ? effectiveStyleDetail
          : (isPhoto ? analysis.style.photoOrArt : null),
      artStyle:
          overrides != null &&
              overrides.enabled &&
              overrides.styleMode == 'art_style' &&
              effectiveStyleDetail != null
          ? effectiveStyleDetail
          : (isPhoto ? null : analysis.style.photoOrArt),
      colorPalette: globalPalette,
    );

    final List<IdeogramElement> elements = <IdeogramElement>[];
    for (int i = 0; i < analysis.objects.length; i++) {
      final VlmObject obj = analysis.objects[i];
      final SamDetection? det = i < detections.length ? detections[i] : null;
      final List<int>? bbox = det?.bbox ?? obj.bbox;
      final List<String>? elemPalette = elementPalettes[obj.name];

      if (obj.hasText) {
        elements.add(
          IdeogramElement(
            type: 'text',
            bbox: bbox,
            desc: obj.desc,
            text: obj.visibleText ?? '',
            colorPalette: elemPalette,
          ),
        );
      } else {
        elements.add(
          IdeogramElement(
            type: 'obj',
            bbox: bbox,
            desc: obj.desc,
            colorPalette: elemPalette,
          ),
        );
      }
    }

    return IdeogramCaption(
      highLevelDescription: analysis.highLevelDescription,
      styleDescription: styleDescription,
      compositionalDeconstruction: IdeogramCompositionalDeconstruction(
        background: effectiveBackground,
        elements: elements,
      ),
    );
  }

  /// Computes center point from [y1, x1, y2, x2] bbox.
  static Point<double>? _center(List<int>? bbox) {
    if (bbox == null || bbox.length != 4) return null;
    return Point<double>((bbox[1] + bbox[3]) / 2, (bbox[0] + bbox[2]) / 2);
  }

  /// Squared distance between two points. Returns infinity if either is null.
  static double _distance(Point<double>? a, Point<double>? b) {
    if (a == null || b == null) return double.infinity;
    return a.squaredDistanceTo(b);
  }
}

/// Helper to carry VLM object bbox pairs through matching.
class VlmObjectBboxPair {
  const VlmObjectBboxPair({required this.name, this.bbox});

  final String name;
  final List<int>? bbox;
}

/// Internal helper for greedy bbox matching.
class _MatchPair {
  const _MatchPair({
    required this.dist,
    required this.samIdx,
    required this.vlmIdx,
  });

  final double dist;
  final int samIdx;
  final int vlmIdx;
}

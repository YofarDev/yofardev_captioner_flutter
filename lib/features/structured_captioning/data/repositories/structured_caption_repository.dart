import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

import '../../../../core/config/service_locator.dart';
import '../../../captioning/data/services/caption_service.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/data/models/structured_batch_overrides.dart';
import '../models/ideogram_caption.dart';
import '../models/vlm_analysis.dart';
import '../services/bbox_highlight_service.dart';
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
  final BboxHighlightService _bboxHighlightService;

  StructuredCaptionRepository({
    CaptionService? captionService,
    SamProcessService? samProcessService,
    ColorExtractionService? colorExtractionService,
    StructuredPromptLoader? promptLoader,
    BboxHighlightService? bboxHighlightService,
  }) : _captionService = captionService ?? CaptionService(),
       _samProcessService = samProcessService ?? SamProcessService(),
       _colorExtractionService =
           colorExtractionService ?? ColorExtractionService(),
       _promptLoader = promptLoader ?? StructuredPromptLoader(),
       _bboxHighlightService =
           bboxHighlightService ?? BboxHighlightService();

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
    bool disableSam = false,
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

    // Step 3: SAM3 detection (skip group elements — SAM detects individuals).
    // When [disableSam] is set, the SAM refinement step is skipped entirely
    // and the VLM-provided bboxes are used directly.
    final List<int> samIndices = <int>[];
    final List<String> samNames = <String>[];
    for (int i = 0; i < analysis.objects.length; i++) {
      final VlmObject obj = analysis.objects[i];
      if (disableSam) {
        continue;
      }
      if (isLikelyGroup(obj.name, obj.desc)) {
        _logger.fine('Skipping SAM for group element: "${obj.name}"');
      } else {
        samIndices.add(i);
        samNames.add(obj.name);
      }
    }

    final List<VlmObjectBboxPair> vlmBboxes = analysis.objects
        .map((VlmObject o) => VlmObjectBboxPair(name: o.name, bbox: o.bbox))
        .toList();

    List<SamDetection> detections = <SamDetection>[];
    if (samNames.isNotEmpty) {
      onProgress(
        'Running SAM detection for ${samNames.length} individual objects…',
      );
      try {
        detections = await _samProcessService.detectObjects(
          imageFile.path,
          samNames,
        );
      } catch (e) {
        _logger.warning('SAM detection failed, using VLM bboxes: $e');
      }
    } else if (disableSam) {
      _logger.info('SAM detection disabled — using VLM bboxes');
    }

    // Step 4: Greedy bbox matching (SAM detections only for individual objects).
    // Build full-length results: SAM-matched for individuals, VLM fallback for groups.
    final List<VlmObjectBboxPair> samVlmBboxes = samIndices
        .map((int i) => vlmBboxes[i])
        .toList();
    final List<SamDetection> samMatched = matchDetectionsToObjects(
      detections,
      samVlmBboxes,
    );

    // Merge back: SAM results at their original positions, VLM bbox for groups.
    final List<SamDetection> matched = List<SamDetection>.filled(
      analysis.objects.length,
      const SamDetection(name: ''),
    );
    for (int i = 0; i < analysis.objects.length; i++) {
      matched[i] = SamDetection(
        name: vlmBboxes[i].name,
        bbox: vlmBboxes[i].bbox,
      );
    }
    for (int j = 0; j < samIndices.length; j++) {
      matched[samIndices[j]] = samMatched[j];
    }

    // Step 5: Per-element color palettes (keyed by index to handle duplicates).
    onProgress('Extracting element palettes...');
    final Map<int, List<String>> elementPalettes = <int, List<String>>{};
    for (int i = 0; i < analysis.objects.length; i++) {
      final List<int>? bbox = i < matched.length
          ? matched[i].bbox
          : analysis.objects[i].bbox;
      if (bbox != null) {
        try {
          final List<String> palette = await _colorExtractionService
              .extractPaletteFromRegion(imageFile, bbox);
          if (palette.isNotEmpty) {
            elementPalettes[i] = palette;
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
    final IdeogramCaption caption = buildIdeogramCaption(
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

  /// Recaptions a single element via one VLM call.
  ///
  /// Sends the full image with the target bbox drawn on it (Approach C),
  /// plus the existing caption JSON for context, plus optional [instructions].
  ///
  /// Returns a NEW [IdeogramElement] with `desc` (and `text` for text elements)
  /// updated. `bbox`, `type`, and `colorPalette` are preserved.
  ///
  /// Throws [RangeError] if [elementIndex] is out of range.
  /// Throws [StateError] if the target element has no bbox.
  /// Throws [FormatException] if the VLM response is missing `desc` or is
  /// unparseable.
  /// Re-throws any error from [CaptionService]; the temp highlight file is
  /// always cleaned up.
  Future<IdeogramElement> recaptionElement({
    required LlmConfig config,
    required File imageFile,
    required IdeogramCaption currentCaption,
    required int elementIndex,
    String? instructions,
  }) async {
    final List<IdeogramElement> elements =
        currentCaption.compositionalDeconstruction.elements;
    if (elementIndex < 0 || elementIndex >= elements.length) {
      throw RangeError('elementIndex $elementIndex out of range');
    }
    final IdeogramElement target = elements[elementIndex];
    final List<int>? bbox = target.bbox;
    if (bbox == null) {
      throw StateError('Target element has no bbox; cannot highlight.');
    }

    final String highlightPath = await _bboxHighlightService
        .renderHighlightedJpeg(imageFile, bbox);

    try {
      final String template = await _promptLoader.loadElementRecaptionPrompt();
      final String prompt = _buildRecaptionPrompt(
        template: template,
        currentCaption: currentCaption,
        elementIndex: elementIndex,
        bbox: bbox,
        instructions: instructions,
      );

      final String raw = await _captionService.getCaption(
        config,
        File(highlightPath),
        prompt,
      );

      return _parseRecaptionResponse(raw, target);
    } finally {
      await _bboxHighlightService.cleanup(highlightPath);
    }
  }

  String _buildRecaptionPrompt({
    required String template,
    required IdeogramCaption currentCaption,
    required int elementIndex,
    required List<int> bbox,
    required String? instructions,
  }) {
    final String instructionsBlock =
        (instructions == null || instructions.isEmpty)
            ? ''
            : 'Additional instructions from the user:\n$instructions\n';
    return template
        .replaceAll('{elementIndex}', elementIndex.toString())
        .replaceAll('{elementBbox}', _fmtBbox(bbox))
        .replaceAll('{existingJson}', currentCaption.toJsonString())
        .replaceAll('{instructionsBlock}', instructionsBlock);
  }

  IdeogramElement _parseRecaptionResponse(
    String raw,
    IdeogramElement target,
  ) {
    final String cleaned = _stripMarkdownFences(raw);
    final Map<String, dynamic> json =
        jsonDecode(cleaned) as Map<String, dynamic>;

    final String desc = (json['desc'] as String?)?.trim() ?? '';
    if (desc.isEmpty) {
      _logger.warning('Recaption response missing desc. Raw: $raw');
      throw const FormatException('Recaption response missing "desc"');
    }
    final bool hasText = (json['has_text'] as bool?) ?? false;
    final String? visibleText = json['visible_text'] as String?;

    if (target.type == 'text') {
      return target.copyWith(
        desc: desc,
        text: hasText ? (visibleText ?? '') : '',
      );
    }
    return target.copyWith(desc: desc);
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
      return parseAnalysisJson(json);
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

  @visibleForTesting
  VlmAnalysis parseAnalysisJson(Map<String, dynamic> json) {
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
  @visibleForTesting
  List<SamDetection> matchDetectionsToObjects(
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
  @visibleForTesting
  IdeogramCaption buildIdeogramCaption(
    List<String> globalPalette,
    VlmAnalysis analysis,
    List<SamDetection> detections,
    Map<int, List<String>> elementPalettes,
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
      final List<String>? elemPalette = elementPalettes[i];

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

  /// Returns true if the VLM element likely represents a group of items
  /// rather than a single individual object.
  ///
  /// Heuristics:
  /// - Name is explicitly plural (ends in 's' but not 'ss' like "glass")
  /// - Description contains group indicators
  @visibleForTesting
  bool isLikelyGroup(String name, String desc) {
    final String lower = name.toLowerCase();

    // Plural name heuristic: ends in 's' but not 'ss' (glass, dress, cross, moss).
    final bool isPlural = lower.endsWith('s') && !lower.endsWith('ss');

    // Description group indicators.
    final String lowerDesc = desc.toLowerCase();
    const List<String> groupKeywords = <String>[
      'group of',
      'cluster of',
      'row of',
      'pair of',
      'collection of',
      'stack of',
      'arrangement of',
      'several ',
      'multiple ',
      'a set of',
      'a bunch of',
    ];
    final bool descHasGroup = groupKeywords.any(
      (String kw) => lowerDesc.contains(kw),
    );

    return isPlural || descHasGroup;
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

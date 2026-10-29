import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/llm_provider_type.dart';
import '../../../../core/models/moss_conversion.dart';
import '../../../../core/models/moss_layout_caption.dart';
import '../../../../core/models/structured_batch_overrides.dart';
import '../../../../core/models/structured_caption_document.dart';
import '../../../../core/services/image_dimension_resolver.dart';
import '../../../../core/utils/cancel_token.dart';
import '../../../../core/utils/image_header_parser.dart';
import '../../../captioning/data/services/caption_service.dart';
import '../../domain/models/multi_stage_quality_report.dart';
import '../../domain/models/structured_mode.dart';
import '../../domain/repositories/structured_caption_repository.dart';
import '../models/vlm_analysis.dart';
import '../services/bbox_highlight_service.dart';
import '../services/color_extraction_service.dart';
import '../services/sam_bbox_service.dart';
// Aliased import so `_buildQualityReport` can call the top-level
// `computeIou` from `sam_bbox_service.dart` without shadowing ambiguity.
import '../services/sam_bbox_service.dart' as bbox_math show computeIou;
import '../services/sam_process_service.dart';
// Aliased re-import so the repository's `computeSamBboxes` member can call the
// same-named top-level function without shadowing ambiguity.
import '../services/sam_process_service.dart' as sam_process;
import '../services/structured_debug_artifacts_writer.dart';
import '../services/structured_prompt_loader.dart';
import '../services/vlm_response_parser.dart';
import '../utils/caption_hardening.dart';

export '../services/sam_bbox_service.dart' show VlmObjectBboxPair;

/// Orchestrates the structured captioning pipeline:
/// global palette → VLM analysis → SAM detection → bbox matching → element
/// palettes → build Ideogram4 JSON.
class StructuredCaptionRepository implements IStructuredCaptionRepository {
  final Logger _logger = Logger('StructuredCaptionRepository');
  final CaptionService _captionService;
  final SamProcessService _samProcessService;
  final ColorExtractionService _colorExtractionService;
  final StructuredPromptLoader _promptLoader;
  final BboxHighlightService _bboxHighlightService;
  final VlmResponseParser _vlmResponseParser;
  final SamBboxService _samBboxService;
  final StructuredDebugArtifactsWriter _debugArtifactsWriter;
  final ImageDimensionLookup _dimensionLookup;

  StructuredCaptionRepository({
    CaptionService? captionService,
    SamProcessService? samProcessService,
    ColorExtractionService? colorExtractionService,
    StructuredPromptLoader? promptLoader,
    BboxHighlightService? bboxHighlightService,
    VlmResponseParser? vlmResponseParser,
    SamBboxService? samBboxService,
    StructuredDebugArtifactsWriter? debugArtifactsWriter,
    ImageDimensionLookup? dimensionLookup,
  }) : _captionService = captionService ?? CaptionService(),
       _samProcessService = samProcessService ?? SamProcessService(),
       _colorExtractionService =
           colorExtractionService ?? ColorExtractionService(),
       _promptLoader = promptLoader ?? StructuredPromptLoader(),
       _bboxHighlightService = bboxHighlightService ?? BboxHighlightService(),
       _vlmResponseParser = vlmResponseParser ?? VlmResponseParser(),
       _samBboxService = samBboxService ?? SamBboxService(),
       _debugArtifactsWriter =
           debugArtifactsWriter ?? const StructuredDebugArtifactsWriter(),
       _dimensionLookup = dimensionLookup ?? defaultDimensionLookup;

  /// Runs the full pipeline on a single image and returns the caption in
  /// [format]'s JSON structure (Ideogram or MOSS layout — the shared VLM/SAM
  /// pipeline is identical, only the final build step and prompt persona
  /// differ).
  ///
  /// [onProgress] emits step descriptions for UI progress tracking.
  /// [debugMode] saves prompt, raw VLM response, bbox overlay and final
  /// caption alongside the image in a debug/ subfolder.
  @override
  Future<Either<Failure, StructuredCaptionDocument>> generateStructuredCaption(
    LlmConfig config,
    File imageFile, {
    required void Function(String step) onProgress,
    CaptionFormat format = CaptionFormat.ideogram,
    StructuredBatchOverrides? overrides,
    bool debugMode = false,
    bool disableSam = false,
    bool vlmEmitsXyxy = true,
    String guidance = '',
    StructuredMode mode = StructuredMode.singleShot,
    CancelToken? cancelToken,
  }) async {
    try {
      // Step 1: Global color palette.
      onProgress('Extracting color palette...');
      List<String> globalPalette = <String>[];
      try {
        globalPalette = await _colorExtractionService.extractPalette(imageFile);
      } catch (e) {
        _logger.warning('Global palette extraction failed: $e');
      }

      // Step 2: VLM analysis — branch on mode.
      final ({String rawPrompt, String rawResponse, VlmAnalysis analysis})
      vision;
      if (mode == StructuredMode.multiStage) {
        vision = await _runVisionAnalysisMultiStage(
          config,
          imageFile,
          onProgress: onProgress,
          format: format,
          vlmEmitsXyxy: vlmEmitsXyxy,
          guidance: guidance,
          debugMode: debugMode,
          cancelToken: cancelToken,
        );
      } else {
        vision = await _runVisionAnalysisSingleShot(
          config,
          imageFile,
          onProgress: onProgress,
          format: format,
          vlmEmitsXyxy: vlmEmitsXyxy,
          guidance: guidance,
          cancelToken: cancelToken,
        );
      }
      final VlmAnalysis analysis = vision.analysis;

      return Right<Failure, StructuredCaptionDocument>(
        await _finalizeCaption(
          config: config,
          imageFile: imageFile,
          format: format,
          analysis: analysis,
          globalPalette: globalPalette,
          vlmRawPrompt: vision.rawPrompt,
          vlmRawResponse: vision.rawResponse,
          onProgress: onProgress,
          overrides: overrides,
          debugMode: debugMode,
          disableSam: disableSam,
          cancelToken: cancelToken,
        ),
      );
    } on CancellationException {
      rethrow;
    } catch (e, st) {
      return Left<Failure, StructuredCaptionDocument>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'StructuredCaptionRepository.generateStructuredCaption',
        ),
      );
    }
  }

  /// Single-shot VLM analysis: one call produces the full VLM JSON. This is
  /// the original structured-captioning vision path; a multi-stage path is
  /// added in a later task.
  Future<({String rawPrompt, String rawResponse, VlmAnalysis analysis})>
  _runVisionAnalysisSingleShot(
    LlmConfig config,
    File imageFile, {
    required void Function(String step) onProgress,
    required CaptionFormat format,
    required bool vlmEmitsXyxy,
    required String guidance,
    CancelToken? cancelToken,
  }) async {
    onProgress('Analyzing image with VLM...');
    // `/no_think` prefix keeps reasoning models from burning the token budget
    // on an internal <think> block; harmless for models that don't recognize it.
    final String prompt = injectNoThink(
      await _buildVisionPrompt(
        imageFile,
        guidance,
        format: format,
        vlmEmitsXyxy: vlmEmitsXyxy,
      ),
    );
    final String vlmRawResponse = await _captionService.getCaption(
      config,
      imageFile,
      prompt,
      // The deconstruction JSON is long; a low provider default would
      // truncate it into malformed JSON. Enforce a sane floor.
      // 8192 comfortably fits complex scenes (crowds, many objects) that
      // easily exceed 4096 tokens. The _parseChatResponse now detects
      // finish_reason="length" and throws a clear error if even this is
      // exceeded.
      maxTokens: _vlmMaxTokens,
      cancelToken: cancelToken,
    );
    // Strip any <think>...</think> the model emitted before its final answer.
    final String vlmCleaned = stripThinking(vlmRawResponse);
    final VlmAnalysis analysis = await _parseVlmResponseWithRepair(
      vlmCleaned,
      config,
      vlmEmitsXyxy: vlmEmitsXyxy,
      cancelToken: cancelToken,
    );
    return (rawPrompt: prompt, rawResponse: vlmRawResponse, analysis: analysis);
  }

  // ponytail: fixed enrich pool of 4 for REMOTE providers (parallel HTTP is
  // cheap). Local MLX MUST run serially: each call spawns a subprocess that
  // reloads the full model into RAM, so N parallel calls load N model copies
  // and freeze the machine. See _enrichConcurrencyFor.
  static const int _enrichConcurrency = 4;

  /// Max completion tokens for VLM caption/enrich requests.
  static const int _vlmMaxTokens = 8192;

  /// Hard cap on the number of elements the enumerate pass may emit.
  /// Enforced both in the prompt and by the pre-enrich validation gate.
  /// Lives on [VlmResponseParser] next to the validation gates.
  static const int _multiStageElementCap =
      VlmResponseParser.multiStageElementCap;

  /// Per-provider enrich fan-out width. Local MLX is forced to 1 (each call is
  /// a heavyweight subprocess that reloads the model); remote providers fan out.
  int _enrichConcurrencyFor(LlmConfig config) =>
      config.providerType == LlmProviderType.localMlx ? 1 : _enrichConcurrency;

  /// Multi-stage vision analysis: enumerate (terse) → validation gate (with
  /// one bounded retry) → quality gate → enrich per eligible element. Returns
  /// the same record shape as [_runVisionAnalysisSingleShot] so the shared
  /// [_finalizeCaption] tail can consume either path uniformly.
  ///
  /// Debug mode saves the enumerate artifacts, per-element enrich artifacts,
  /// and a quality report alongside the standard debug output.
  Future<({String rawPrompt, String rawResponse, VlmAnalysis analysis})>
  _runVisionAnalysisMultiStage(
    LlmConfig config,
    File imageFile, {
    required void Function(String step) onProgress,
    required CaptionFormat format,
    required bool vlmEmitsXyxy,
    required String guidance,
    bool debugMode = false,
    CancelToken? cancelToken,
  }) async {
    // ── Pass 1: enumerate ───────────────────────────────────────────────
    onProgress('Enumerating objects (multi-stage VLM)...');
    String prompt = injectNoThink(
      await _buildEnumeratePrompt(
        imageFile,
        guidance,
        format: format,
        vlmEmitsXyxy: vlmEmitsXyxy,
      ),
    );
    String rawResponse = await _captionService.getCaption(
      config,
      imageFile,
      prompt,
      maxTokens: _vlmMaxTokens,
      cancelToken: cancelToken,
    );
    VlmAnalysis analysis = await _parseEnumerateResponse(
      rawResponse,
      config,
      vlmEmitsXyxy: vlmEmitsXyxy,
      cancelToken: cancelToken,
    );
    bool didRetry = false;
    String? retryPrompt;
    String? retryRawResponse;

    // ── Validation gate ────────────────────────────────────────────────
    final List<String> defects = _validateEnumerateOutput(analysis);
    if (defects.isNotEmpty) {
      _logger.warning(
        'Enumerate validation found ${defects.length} defect(s): '
        '${defects.join("; ")}',
      );
      // One bounded retry with defect feedback.
      didRetry = true;
      retryPrompt = injectNoThink(
        await _buildEnumeratePrompt(
          imageFile,
          '$guidance\n\n## PREVIOUS ATTEMPT DEFECTS — fix these issues:\nYour previous output had these structural problems:\n- ${defects.join("\n- ")}\nPlease fix ALL of the above issues in your new output. Prioritize broad coverage over filling the element cap.',
          format: format,
          vlmEmitsXyxy: vlmEmitsXyxy,
        ),
      );
      retryRawResponse = await _captionService.getCaption(
        config,
        imageFile,
        retryPrompt,
        maxTokens: _vlmMaxTokens,
        cancelToken: cancelToken,
      );
      final VlmAnalysis retryAnalysis = await _parseEnumerateResponse(
        retryRawResponse,
        config,
        vlmEmitsXyxy: vlmEmitsXyxy,
        cancelToken: cancelToken,
      );
      // Use the retry output if it has objects, even if still imperfect.
      // The original analysis is kept as fallback only if retry is empty.
      if (retryAnalysis.objects.isNotEmpty) {
        analysis = retryAnalysis;
        prompt = retryPrompt;
        rawResponse = retryRawResponse;
      }
    }

    if (analysis.objects.isEmpty) {
      return (rawPrompt: prompt, rawResponse: rawResponse, analysis: analysis);
    }

    // ── Quality gates: prune duplicates, skip suspicious bboxes ────────
    analysis = _vlmResponseParser.pruneDuplicateObjects(analysis);
    final MultiStageQualityReport qualityReport = _buildQualityReport(analysis);
    final List<int> skippedIndices = <int>[
      ...qualityReport.fullCanvasBboxes,
      ...qualityReport.nearFullCanvasBboxes,
    ];

    final List<int> enrichableIndices = <int>[];
    for (int i = 0; i < analysis.objects.length; i++) {
      if (!skippedIndices.contains(i)) {
        enrichableIndices.add(i);
      }
    }
    if (enrichableIndices.isEmpty) {
      return (rawPrompt: prompt, rawResponse: rawResponse, analysis: analysis);
    }

    // ── Enrichment fan-out ─────────────────────────────────────────────
    onProgress('Enriching ${enrichableIndices.length} elements...');
    final List<VlmObject?> enrichResults = await _enrichObjects(
      config,
      imageFile,
      enrichableIndices.map((int i) => analysis.objects[i]).toList(),
      onProgress,
      cancelToken: cancelToken,
    );

    // Merge enriched results back into the full object list.
    final List<VlmObject> merged = List<VlmObject>.from(analysis.objects);
    final List<int> failureIndices = <int>[];
    for (int j = 0; j < enrichableIndices.length; j++) {
      final VlmObject? enriched = enrichResults[j];
      if (enriched != null) {
        merged[enrichableIndices[j]] = enriched;
      } else {
        failureIndices.add(enrichableIndices[j]);
      }
    }

    final VlmAnalysis enrichedAnalysis = VlmAnalysis(
      highLevelDescription: analysis.highLevelDescription,
      style: analysis.style,
      background: analysis.background,
      objects: merged,
    );

    // Debug artifacts for multi-stage.
    if (debugMode) {
      await _debugArtifactsWriter.saveMultiStage(
        imageFile: imageFile,
        enumeratePrompt: didRetry ? retryPrompt! : prompt,
        enumerateRawResponse: didRetry ? retryRawResponse! : rawResponse,
        qualityReport: qualityReport,
        enrichFailures: failureIndices,
        preEnrichAnalysis: analysis,
      );
    }

    return (
      rawPrompt: prompt,
      rawResponse: rawResponse,
      analysis: enrichedAnalysis,
    );
  }

  /// Parses an enumerate VLM response, falling back to partial recovery on
  /// malformed JSON.
  Future<VlmAnalysis> _parseEnumerateResponse(
    String raw,
    LlmConfig config, {
    bool vlmEmitsXyxy = true,
    CancelToken? cancelToken,
  }) => _vlmResponseParser.parseEnumerateResponse(
    raw,
    parseWithRepair: (String raw, {bool vlmEmitsXyxy = true}) =>
        _parseVlmResponseWithRepair(
          raw,
          config,
          vlmEmitsXyxy: vlmEmitsXyxy,
          cancelToken: cancelToken,
        ),
    vlmEmitsXyxy: vlmEmitsXyxy,
  );

  // ── bbox quality helpers ────────────────────────────────────────────────

  /// True when [bbox] is the exact full-canvas `[0, 0, 1000, 1000]`.
  bool _isFullCanvasBbox(List<int>? bbox) =>
      _vlmResponseParser.isFullCanvasBbox(bbox);

  /// True when [bbox] covers more than 80 % of the full canvas.
  bool _isNearFullCanvasBbox(List<int>? bbox) =>
      _vlmResponseParser.isNearFullCanvasBbox(bbox);

  /// Builds a quality report for the multi-stage analysis, identifying
  /// full-canvas, near-full-canvas, and duplicate-prone elements.
  MultiStageQualityReport _buildQualityReport(VlmAnalysis analysis) {
    final List<int> fullCanvas = <int>[];
    final List<int> nearFullCanvas = <int>[];
    final List<int> duplicates = <int>[];
    final Set<int> seen = <int>{};

    for (int i = 0; i < analysis.objects.length; i++) {
      final List<int>? bbox = analysis.objects[i].bbox;
      if (_isFullCanvasBbox(bbox)) {
        fullCanvas.add(i);
      } else if (_isNearFullCanvasBbox(bbox)) {
        nearFullCanvas.add(i);
      }
      // Duplicate candidate detection (already pruned, but report what was
      // found before pruning — we can only report what remains).
      for (final int s in seen) {
        final double iou = bbox_math.computeIou(
          analysis.objects[s].bbox,
          analysis.objects[i].bbox,
        );
        if (iou > VlmResponseParser.duplicateIouThreshold &&
            _vlmResponseParser.normalizedNameSimilarity(
                  analysis.objects[s].name,
                  analysis.objects[i].name,
                ) >
                VlmResponseParser.duplicateNameSimilarityThreshold) {
          duplicates.add(i);
          break;
        }
      }
      seen.add(i);
    }

    return MultiStageQualityReport(
      fullCanvasBboxes: fullCanvas,
      nearFullCanvasBboxes: nearFullCanvas,
      duplicateCandidates: duplicates,
    );
  }

  /// Builds the enumerate prompt, mirroring [_buildVisionPrompt] but loading
  /// the enumerate template.
  Future<String> _buildEnumeratePrompt(
    File imageFile,
    String guidance, {
    required CaptionFormat format,
    bool vlmEmitsXyxy = true,
  }) async {
    final String template = await _promptLoader.loadVisionEnumeratePrompt();
    final String aspectRatio = await _aspectRatioOfFile(imageFile);
    final String bboxOrder = vlmEmitsXyxy ? 'x1, y1, x2, y2' : 'y1, x1, y2, x2';
    String prompt = _substituteFormatTokens(template, format)
        .replaceAll('{{aspect_ratio}}', aspectRatio)
        .replaceAll('{{bbox_order}}', bboxOrder)
        .replaceAll('{{element_cap}}', _multiStageElementCap.toString());
    if (guidance.trim().isNotEmpty) {
      prompt +=
          '\n\n## PER-IMAGE USER GUIDANCE (authoritative)\n'
          'The instructions below are supplied by the user for THIS specific '
          'image. Follow them exactly.\n\nUSER GUIDANCE:\n$guidance';
    }
    return prompt;
  }

  /// Validates enumerate output before enrichment fan-out.
  ///
  /// Returns a list of structural defect descriptions. An empty list means
  /// the output is structurally sound and enrichment can proceed.
  List<String> _validateEnumerateOutput(VlmAnalysis analysis) =>
      _vlmResponseParser.validateEnumerateOutput(analysis);

  /// Post-merge structural defect check for the final analysis.
  ///
  /// Runs after enrichment merges and before SAM/palette work. Either warns
  /// or (for cap violations) throws — it does not trigger a retry.
  List<String> _postMergeDefects(VlmAnalysis analysis) =>
      _vlmResponseParser.postMergeDefects(analysis);

  /// Runs the per-element enrich fan-out. Width is provider-aware via
  /// [_enrichConcurrencyFor]: serial (1) for local MLX so we never load
  /// multiple model copies, parallel (up to [_enrichConcurrency]) for remote.
  /// Objects that fail to enrich (throw / unparseable / no bbox) keep their
  /// terse enumerate desc — one bad element never fails the image.
  Future<List<VlmObject>> _enrichObjects(
    LlmConfig config,
    File imageFile,
    List<VlmObject> objects,
    void Function(String step) onProgress, {
    CancelToken? cancelToken,
  }) async {
    final List<VlmObject> result = List<VlmObject>.from(objects);
    final int concurrency = _enrichConcurrencyFor(config);
    int done = 0;
    for (int i = 0; i < objects.length; i += concurrency) {
      final int end = (i + concurrency).clamp(0, objects.length);
      final List<int> chunk = <int>[for (int j = i; j < end; j++) j];
      final List<VlmObject?> outcomes = await Future.wait(<Future<VlmObject?>>[
        for (final int idx in chunk)
          _enrichOne(config, imageFile, objects[idx], cancelToken: cancelToken),
      ]);
      for (int k = 0; k < chunk.length; k++) {
        final VlmObject? e = outcomes[k];
        if (e != null) {
          result[chunk[k]] = e;
        }
      }
      done += chunk.length;
      onProgress('Enriched $done/${objects.length} elements...');
    }
    return result;
  }

  /// Enriches a single element via one VLM call on its cropped region.
  /// Returns null on any failure or sanity-check rejection → caller keeps the
  /// terse enumerate desc.
  Future<VlmObject?> _enrichOne(
    LlmConfig config,
    File imageFile,
    VlmObject obj, {
    CancelToken? cancelToken,
  }) async {
    final List<int>? bbox = obj.bbox;
    if (bbox == null) {
      return null;
    }
    String? tempPath;
    try {
      tempPath = await _bboxHighlightService.renderCroppedJpeg(imageFile, bbox);
      final String template = await _promptLoader.loadElementEnrichPrompt();
      final String prompt = template
          .replaceAll('{name}', obj.name)
          .replaceAll('{type}', obj.type)
          .replaceAll('{desc}', obj.desc)
          .replaceAll('{bbox}', _fmtBbox(bbox));
      final String raw = await _captionService.getCaption(
        config,
        File(tempPath),
        prompt,
        cancelToken: cancelToken,
      );
      final VlmObject? parsed = _parseEnrichResponse(raw, obj);
      if (parsed == null) return null;
      // Sanity check: reject descriptions that clearly describe the whole
      // scene instead of the cropped element.
      if (!_enrichResponsePassesSanity(parsed)) {
        _logger.warning('Enrich sanity check failed for "${obj.name}"');
        return null;
      }
      return parsed;
    } on CancellationException {
      rethrow;
    } catch (e) {
      // Deliberate soft-fail: one unparseable element must not abort the whole
      // run — the element keeps its un-enriched description and the run
      // continues. The failure is logged here, once, at the boundary.
      _logger.warning('Element enrich failed for "${obj.name}": $e');
      return null;
    } finally {
      if (tempPath != null) {
        try {
          await _bboxHighlightService.cleanup(tempPath);
        } catch (e) {
          _logger.warning(
            'Element enrich cleanup failed for "${obj.name}": $e',
          );
        }
      }
    }
  }

  /// Sanity check for a single-element enrich response.
  ///
  /// Rejects descriptions that:
  /// - Refer to the whole scene instead of the cropped element
  /// - Are too short (< 5 words) — insufficient enrichment
  /// - Are too long (> 80 words) — likely padding or hallucination
  /// - Describe a different subject than the original element name
  ///
  /// The word-count bounds are intentionally generous — they catch the worst
  /// cases without rejecting legitimate concise descriptions for small objects.
  bool _enrichResponsePassesSanity(VlmObject obj) {
    final String desc = obj.desc.toLowerCase();
    // Whole-scene indicators that a single-element crop should never mention.
    const List<String> scenePhrases = <String>[
      'the room',
      'the scene',
      'the image',
      'the whole',
      'the background',
      'the foreground',
      'the setting',
      'the environment',
      'the composition',
      'the layout',
      'in this image',
      'in the scene',
      'in the room',
      'this image shows',
      'the overall',
      'the entire',
    ];
    if (scenePhrases.any((String phrase) => desc.contains(phrase))) {
      _logger.fine(
        'Enrich sanity rejected: scene phrase in "${obj.name}": "$desc"',
      );
      return false;
    }

    // Word count check.
    final int wordCount = desc
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .length;
    if (wordCount < 5) {
      _logger.fine(
        'Enrich sanity rejected: too short (${wordCount}w) for "${obj.name}"',
      );
      return false;
    }
    if (wordCount > 80) {
      _logger.fine(
        'Enrich sanity rejected: too long (${wordCount}w) for "${obj.name}"',
      );
      return false;
    }

    return true;
  }

  /// Parses a single-element enrich JSON response into a new [VlmObject]
  /// carrying the rich desc. Returns null when the response is missing `desc`
  /// or is unparseable (caller then retains the terse desc).
  VlmObject? _parseEnrichResponse(String raw, VlmObject original) =>
      _vlmResponseParser.parseEnrichResponse(raw, original);

  /// Shared tail for both vision paths: health check → SAM → element
  /// palettes → build the format-specific JSON → optional debug artifacts.
  Future<StructuredCaptionDocument> _finalizeCaption({
    required LlmConfig config,
    required File imageFile,
    required CaptionFormat format,
    required VlmAnalysis analysis,
    required List<String> globalPalette,
    required String vlmRawPrompt,
    required String vlmRawResponse,
    required void Function(String step) onProgress,
    StructuredBatchOverrides? overrides,
    bool debugMode = false,
    bool disableSam = false,
    CancelToken? cancelToken,
  }) async {
    // Cheap structural health check before spending SAM + palette work on a
    // refusal / empty / degenerate output. Fatal issues abort the image
    // (retryable); soft issues are logged.
    final List<String> healthIssues = captionHealthIssues(analysis);
    if (hasFatalHealthIssue(healthIssues)) {
      throw FormatException(
        'VLM produced unusable output: ${healthIssues.join('; ')}',
      );
    }
    for (final String issue in healthIssues) {
      _logger.warning('Caption health issue for ${imageFile.path}: $issue');
    }
    _logger.info('VLM analysis parsed: ${analysis.objects.length} objects');

    // Post-merge consistency invariants. These are hard checks that catch
    // structural defects even after the multi-stage pipeline completes.
    final List<String> postDefects = _postMergeDefects(analysis);
    if (postDefects.isNotEmpty) {
      for (final String defect in postDefects) {
        _logger.warning(
          'Final caption integrity issue for ${imageFile.path}: $defect',
        );
      }
      // Cap violation is a hard failure — it means the element cap was
      // exceeded even after VLM-level enforcement.
      if (postDefects.any((String d) => d.contains('element cap exceeded'))) {
        throw FormatException(
          'Final caption exceeds element cap: ${postDefects.join('; ')}',
        );
      }
    }

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
      if (_samBboxService.isLikelyGroup(obj.name, obj.desc)) {
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
        // Pass each SAM-eligible object's VLM bbox as a box prompt so SAM3
        // refines the indicated region instead of running a free-form text
        // search (which can latch onto a wrong same-concept object). A null
        // entry means the VLM supplied no bbox for that object → text-only.
        final List<List<int>?> samBoxHints = samIndices
            .map((int i) => vlmBboxes[i].bbox)
            .toList();
        detections = await _samProcessService.detectObjects(
          imageFile.path,
          samNames,
          vlmBboxes: samBoxHints,
          cancelToken: cancelToken,
        );
      } on CancellationException {
        rethrow;
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
    final List<SamDetection> samMatched = _samBboxService
        .matchDetectionsToObjects(detections, samVlmBboxes);

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

    // Step 6: Build the format-specific JSON.
    onProgress('Building structured caption...');
    if (format == CaptionFormat.moss) {
      final ImageDimensions? dims = await _dimensionsOfFile(imageFile);
      if (dims == null) {
        // Surfaced as a Failure by the caller's exception mapping — MOSS
        // generation must not fall back to an invented 1024×1024 canvas.
        throw StateError(
          'image dimensions could not be read; refusing to generate a MOSS '
          'layout on an invented canvas',
        );
      }
      final MossLayoutCaption caption = buildMossLayoutCaption(
        globalPalette,
        analysis,
        matched,
        elementPalettes,
        overrides,
        width: dims.width,
        height: dims.height,
      );
      if (debugMode) {
        onProgress('Saving debug artifacts...');
        await _debugArtifactsWriter.save(
          imageFile: imageFile,
          prompt: vlmRawPrompt,
          vlmRawResponse: vlmRawResponse,
          vlmObjects: analysis.objects,
          detections: matched,
          caption: MossDocument(caption: caption),
        );
      }
      return MossDocument(caption: caption);
    }
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
      await _debugArtifactsWriter.save(
        imageFile: imageFile,
        prompt: vlmRawPrompt,
        vlmRawResponse: vlmRawResponse,
        vlmObjects: analysis.objects,
        detections: matched,
        caption: IdeogramDocument(caption: caption),
      );
    }

    return IdeogramDocument(caption: caption);
  }

  /// Resolves the image's exact decoded dimensions (header fast path, full
  /// decode fallback with EXIF baked). Returns null when unreadable — MOSS
  /// generation fails visibly instead of assuming 1024×1024.
  Future<ImageDimensions?> _dimensionsOfFile(File imageFile) =>
      _dimensionLookup(imageFile);

  /// Runs SAM3 detection for the elements of [caption] that have a bbox and
  /// are not likely-group elements. Returns a sparse map of
  /// `original element index → SAM-refined bbox` in `[y1, x1, y2, x2]`
  /// 0-1000 normalized coordinates.
  ///
  /// Delegates to the top-level `computeSamBboxes` in
  /// `sam_process_service.dart`, passing this repository's injected
  /// [SamProcessService.detectObjects] as the SAM entry point. The SAM
  /// subprocess's own soft-fails are logged there and come back as
  /// `Right({})`; other errors surface as `Left(Failure)`.
  @override
  Future<Either<Failure, Map<int, List<int>>>> computeSamBboxes({
    required File imageFile,
    required IdeogramCaption caption,
  }) async {
    try {
      final Map<int, List<int>> result = await sam_process.computeSamBboxes(
        imageFile: imageFile,
        caption: caption,
        detect: _samProcessService.detectObjects,
      );
      return Right<Failure, Map<int, List<int>>>(result);
    } on CancellationException {
      rethrow;
    } catch (e, st) {
      return Left<Failure, Map<int, List<int>>>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'StructuredCaptionRepository.computeSamBboxes',
        ),
      );
    }
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
  @override
  Future<Either<Failure, IdeogramElement>> recaptionElement({
    required LlmConfig config,
    required File imageFile,
    required IdeogramCaption currentCaption,
    required int elementIndex,
    String? instructions,
    bool cropToBbox = false,
  }) async {
    try {
      return Right<Failure, IdeogramElement>(
        await _recaptionElement(
          config: config,
          imageFile: imageFile,
          currentCaption: currentCaption,
          elementIndex: elementIndex,
          instructions: instructions,
          cropToBbox: cropToBbox,
        ),
      );
    } on CancellationException {
      rethrow;
    } catch (e, st) {
      return Left<Failure, IdeogramElement>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'StructuredCaptionRepository.recaptionElement',
        ),
      );
    }
  }

  Future<IdeogramElement> _recaptionElement({
    required LlmConfig config,
    required File imageFile,
    required IdeogramCaption currentCaption,
    required int elementIndex,
    String? instructions,
    bool cropToBbox = false,
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

    final String imagePath = cropToBbox
        ? await _bboxHighlightService.renderCroppedJpeg(imageFile, bbox)
        : await _bboxHighlightService.renderHighlightedJpeg(imageFile, bbox);

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
        File(imagePath),
        prompt,
      );

      return _parseRecaptionResponse(raw, target);
    } finally {
      await _bboxHighlightService.cleanup(imagePath);
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
        .replaceAll('{instructionsBlock}', instructionsBlock)
        .replaceAll('{existingJson}', currentCaption.toJsonString());
  }

  /// Recaptions ONLY the four style fields (medium, photo/art, aesthetics,
  /// lighting) via one VLM call on the full image. The existing
  /// [IdeogramStyleDescription.colorPalette] is preserved — it has its own
  /// extraction flow.
  ///
  /// Returns a NEW [IdeogramStyleDescription] with all four text fields swapped
  /// from the VLM response. If the VLM flips `medium` (e.g. photograph →
  /// painting), the `photo`/`artStyle` field switches type accordingly, the
  /// same way a fresh full caption would.
  ///
  /// Throws [FormatException] if the response is missing `medium`, is not a
  /// JSON object, or is otherwise unparseable. Re-throws any error from
  /// [CaptionService].
  @override
  Future<Either<Failure, IdeogramStyleDescription>> recaptionStyle({
    required LlmConfig config,
    required File imageFile,
    required IdeogramCaption currentCaption,
  }) async {
    try {
      return Right<Failure, IdeogramStyleDescription>(
        await _recaptionStyle(
          config: config,
          imageFile: imageFile,
          currentCaption: currentCaption,
        ),
      );
    } on CancellationException {
      rethrow;
    } catch (e, st) {
      return Left<Failure, IdeogramStyleDescription>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'StructuredCaptionRepository.recaptionStyle',
        ),
      );
    }
  }

  Future<IdeogramStyleDescription> _recaptionStyle({
    required LlmConfig config,
    required File imageFile,
    required IdeogramCaption currentCaption,
  }) async {
    final String template = await _promptLoader.loadStyleRecaptionPrompt();
    final String prompt = template.replaceAll(
      '{existingJson}',
      currentCaption.toJsonString(),
    );

    final String raw = await _captionService.getCaption(
      config,
      imageFile,
      prompt,
    );

    return _mapStyleResponse(raw, currentCaption.styleDescription.colorPalette);
  }

  /// Parses the style-recaption VLM response and maps it to an
  /// [IdeogramStyleDescription], routing `photo_or_art` into `photo` or
  /// `artStyle` based on `medium` (mirroring [buildIdeogramCaption]).
  IdeogramStyleDescription mapStyleResponse(
    String raw,
    List<String> colorPalette,
  ) => _mapStyleResponse(raw, colorPalette);

  IdeogramStyleDescription _mapStyleResponse(
    String raw,
    List<String> colorPalette,
  ) {
    final Map<String, dynamic> json;
    final String medium;
    try {
      final String cleaned = _vlmResponseParser.stripMarkdownFences(raw);
      json = jsonDecode(cleaned) as Map<String, dynamic>;
      medium = (json['medium'] as String?)?.trim() ?? '';
    } catch (e) {
      _logger.warning('Failed to parse style recaption response: $e');
      _logger.fine('Raw response was: $raw');
      throw FormatException('Failed to parse style recaption JSON: $e');
    }

    if (medium.isEmpty) {
      _logger.warning('Style recaption response missing medium. Raw: $raw');
      throw const FormatException('Style recaption response missing "medium"');
    }

    final String aesthetics = (json['aesthetics'] as String?)?.trim() ?? '';
    final String lighting = (json['lighting'] as String?)?.trim() ?? '';
    final String photoOrArt = (json['photo_or_art'] as String?)?.trim() ?? '';
    final bool isPhoto = medium == 'photograph';

    return IdeogramStyleDescription(
      aesthetics: aesthetics,
      lighting: lighting,
      medium: medium,
      photo: isPhoto ? photoOrArt : null,
      artStyle: isPhoto ? null : photoOrArt,
      colorPalette: colorPalette,
    );
  }

  /// Builds the vision-analysis prompt, injecting the image's real aspect
  /// ratio so the VLM sizes bboxes correctly (a `[0,0,500,500]` box is square
  /// only on a square frame). When [guidance] is non-empty it is appended as
  /// an authoritative per-image instruction block that overrides the base
  /// rules — letting the user name a subject, force a split, or skip an
  /// attribute for this one image.
  Future<String> _buildVisionPrompt(
    File imageFile,
    String guidance, {
    required CaptionFormat format,
    bool vlmEmitsXyxy = true,
  }) async {
    final String template = await _promptLoader.loadVisionAnalysisPrompt();
    final String aspectRatio = await _aspectRatioOfFile(imageFile);
    // Ask the VLM for whichever bbox order it actually emits well. The stored
    // Ideogram4 JSON is always yxyx — the normalizer reinterprets the response
    // using the same flag, so asking + interpreting must agree here.
    final String bboxOrder = vlmEmitsXyxy ? 'x1, y1, x2, y2' : 'y1, x1, y2, x2';
    String prompt = _substituteFormatTokens(template, format)
        .replaceAll('{{aspect_ratio}}', aspectRatio)
        .replaceAll('{{bbox_order}}', bboxOrder);
    if (guidance.trim().isNotEmpty) {
      prompt +=
          '\n\n## PER-IMAGE USER GUIDANCE (authoritative)\n'
          'The instructions below are supplied by the user for THIS specific '
          'image. Follow them exactly. Where they conflict with the rules '
          'above, this guidance takes precedence — for example you MAY emit '
          'a part, prop, or held object as its own separate element, or omit '
          'attributes the user tells you to skip.\n\n'
          'USER GUIDANCE:\n$guidance';
    }
    return prompt;
  }

  /// Substitutes the format-persona tokens shared by both vision prompts.
  /// Ideogram keeps its established contract; MOSS adds the `character`
  /// label with an inline definition (the prompt templates are otherwise
  /// identical — both formats share the whole observe-only pipeline).
  String _substituteFormatTokens(String template, CaptionFormat format) {
    final String targetModel = format == CaptionFormat.moss
        ? 'MOSS-Image'
        : 'Ideogram 4';
    final String typeContract = format == CaptionFormat.moss
        ? 'obj | character | text — character = a person, animal or '
              'anthropomorphic being; obj = every other physical object'
        : 'obj | text';
    return template
        .replaceAll('{{target_model}}', targetModel)
        .replaceAll('{{type_contract}}', typeContract);
  }

  /// Computes a clean `W:H` aspect-ratio string for [imageFile], snapped to a
  /// small denominator (≤16) so it matches the generator's ratio distribution
  /// instead of ugly fractions like `1023:768`. Returns `1:1` on failure.
  @visibleForTesting
  String computeAspectRatio(int width, int height) {
    if (width <= 0 || height <= 0) return '1:1';
    final int g = width.gcd(height);
    final int rw = width ~/ g;
    final int rh = height ~/ g;
    if (rw <= 16 && rh <= 16) return '$rw:$rh';
    // Snap to the closest p:q with q ≤ 16.
    const int maxDenom = 16;
    final double target = width / height;
    int bestP = 1;
    int bestQ = 1;
    double bestErr = double.infinity;
    for (int q = 1; q <= maxDenom; q++) {
      final int p = max(1, (target * q).round());
      final double err = (p / q - target).abs();
      if (err < bestErr) {
        bestErr = err;
        bestP = p;
        bestQ = q;
      }
    }
    return '$bestP:$bestQ';
  }

  Future<String> _aspectRatioOfFile(File imageFile) async {
    try {
      // Header-only parse first — never pay a full pixel decode for W×H.
      final ImageHeader? header = await ImageHeaderParser.parseFile(imageFile);
      if (header != null) {
        return computeAspectRatio(header.width, header.height);
      }
      // Rare formats (GIF/BMP/TIFF): decode off the UI isolate.
      final Uint8List bytes = await imageFile.readAsBytes();
      final ({int width, int height})? dims =
          await Isolate.run<({int width, int height})?>(() {
            final img.Image? decoded = img.decodeImage(bytes);
            if (decoded == null) {
              return null;
            }
            return (width: decoded.width, height: decoded.height);
          });
      if (dims == null) {
        return '1:1';
      }
      return computeAspectRatio(dims.width, dims.height);
    } catch (e) {
      _logger.fine(
        '_aspectRatioOfFile: falling back to 1:1 for ${imageFile.path}: $e',
      );
      return '1:1';
    }
  }

  IdeogramElement _parseRecaptionResponse(String raw, IdeogramElement target) {
    final Map<String, dynamic> json;
    final String desc;
    try {
      final String cleaned = _vlmResponseParser.stripMarkdownFences(raw);
      json = jsonDecode(cleaned) as Map<String, dynamic>;
      desc = (json['desc'] as String?)?.trim() ?? '';
    } catch (e) {
      _logger.warning('Failed to parse recaption response: $e');
      _logger.fine('Raw response was: $raw');
      throw FormatException('Failed to parse recaption JSON response: $e');
    }

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

  /// Formats a [y1, x1, y2, x2] bbox as a readable string.
  String _fmtBbox(List<int>? bbox) {
    if (bbox == null) return 'none';
    return '[${bbox[0]}, ${bbox[1]}, ${bbox[2]}, ${bbox[3]}]';
  }

  /// Parses the VLM response string into a [VlmAnalysis], delegating the
  /// textual interpretation to [VlmResponseParser].
  VlmAnalysis _parseVlmResponse(String raw, {bool vlmEmitsXyxy = true}) =>
      _vlmResponseParser.parseVlmResponse(raw, vlmEmitsXyxy: vlmEmitsXyxy);

  /// Parses the VLM response into a [VlmAnalysis], retrying once via a
  /// JSON-repair LLM call when the first parse fails. Repair is text-only and
  /// unavailable for local MLX providers — in that case the original parse
  /// error is rethrown so the image is marked failed and stays retryable.
  Future<VlmAnalysis> _parseVlmResponseWithRepair(
    String raw,
    LlmConfig config, {
    bool vlmEmitsXyxy = true,
    CancelToken? cancelToken,
  }) async {
    try {
      return _parseVlmResponse(raw, vlmEmitsXyxy: vlmEmitsXyxy);
    } on FormatException catch (firstError) {
      _logger.warning(
        'VLM JSON parse failed; attempting model-side repair: $firstError',
      );
      try {
        final String repaired = await _captionService.repairJson(
          config,
          raw,
          maxTokens: _vlmMaxTokens,
          cancelToken: cancelToken,
        );
        return _parseVlmResponse(
          stripThinking(repaired),
          vlmEmitsXyxy: vlmEmitsXyxy,
        );
      } on CancellationException {
        rethrow;
      } catch (repairError) {
        _logger.warning('JSON repair retry failed: $repairError');
        throw FormatException(
          'Failed to parse VLM JSON response and repair retry failed: '
          '$firstError',
        );
      }
    }
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

      if (obj.type == 'text') {
        elements.add(
          IdeogramElement(
            type: 'text',
            bbox: bbox,
            desc: obj.desc,
            text: obj.text ?? '',
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

  /// Builds the final [MossLayoutCaption] from pipeline data — the MOSS
  /// counterpart of [buildIdeogramCaption], sharing the same override
  /// resolution. Style fields become flat `summary.meta` tags; the
  /// VLM `name` is preserved as the item's `tags` entry. Elements without a
  /// bbox are dropped (every MOSS item requires one).
  @visibleForTesting
  MossLayoutCaption buildMossLayoutCaption(
    List<String> globalPalette,
    VlmAnalysis analysis,
    List<SamDetection> detections,
    Map<int, List<String>> elementPalettes,
    StructuredBatchOverrides? overrides, {
    required int width,
    required int height,
  }) {
    final IdeogramCaption ideogramView = buildIdeogramCaption(
      globalPalette,
      analysis,
      detections,
      elementPalettes,
      null,
    );

    // Same override resolution as buildIdeogramCaption, expressed on the
    // fields that land in summary.
    final String effectiveBackground =
        overrides != null &&
            overrides.enabled &&
            overrides.overrideBackground &&
            overrides.background != null
        ? overrides.background!
        : analysis.background;
    final String? effectiveStyleDetail =
        overrides != null &&
            overrides.enabled &&
            overrides.styleMode != null &&
            overrides.styleDetail != null
        ? overrides.styleDetail
        : (ideogramView.styleDescription.medium == 'photograph'
              ? ideogramView.styleDescription.photo
              : ideogramView.styleDescription.artStyle);

    final IdeogramStyleDescription style = ideogramView.styleDescription;
    final String summaryCaption = effectiveBackground.isEmpty
        ? ideogramView.highLevelDescription
        : '${ideogramView.highLevelDescription} $effectiveBackground';

    final List<MossItem> items = <MossItem>[];
    for (int i = 0; i < analysis.objects.length; i++) {
      final VlmObject obj = analysis.objects[i];
      final SamDetection? det = i < detections.length ? detections[i] : null;
      final List<int>? bbox = det?.bbox ?? obj.bbox;
      if (bbox == null) {
        continue;
      }
      final List<int>? pixelBbox = normalizedToPixelBbox(
        bbox,
        width: width,
        height: height,
      );
      if (pixelBbox == null) {
        continue;
      }
      final bool isText = obj.type == 'text';
      items.add(
        MossItem(
          label: isText
              ? 'text'
              : (obj.type == 'character' ? 'character' : 'object'),
          caption: obj.desc,
          text: isText ? (obj.text ?? '') : null,
          bbox: pixelBbox,
          tags: <String>[obj.name],
          palette: elementPalettes[i] ?? const <String>[],
        ),
      );
    }

    return MossLayoutCaption(
      width: width,
      height: height,
      summary: MossSummary(
        caption: summaryCaption,
        meta: <String>[
          style.medium,
          ...style.aesthetics
              .split(',')
              .map((String s) => s.trim())
              .where((String s) => s.isNotEmpty),
          if (style.lighting.isNotEmpty) style.lighting,
          if (effectiveStyleDetail?.isNotEmpty == true) effectiveStyleDetail!,
        ],
        palette: globalPalette,
      ),
      items: items,
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/utils/cancel_token.dart';
import '../../../../core/utils/process_runner.dart';
import 'sam_bbox_service.dart';

/// Detection result from SAM3 for a single object.
class SamDetection {
  const SamDetection({required this.name, this.bbox});

  /// Object name matching the prompt.
  final String name;

  /// Bounding box [y1, x1, y2, x2] in 0-1000 normalized coordinates.
  /// Null when SAM failed to detect this object.
  final List<int>? bbox;
}

/// Calls the Python SAM3 wrapper via [ProcessRunner].
///
/// The wrapper script is bundled as an asset and extracted to the application
/// support directory on first use. Requires Python 3 with mlx-vlm and Pillow.
class SamProcessService {
  final Logger _logger = locator<Logger>();
  final ProcessRunner _processRunner;

  static const String _scriptAsset = 'assets/scripts/sam3_wrapper.py';
  static const String _scriptFileName = 'sam3_wrapper.py';

  /// Optional override for the wrapper script path (used in tests).
  @visibleForTesting
  String? scriptPathOverride;

  SamProcessService({ProcessRunner? processRunner})
    : _processRunner = processRunner ?? const ProcessRunner();

  /// Returns the path to the extracted SAM wrapper script.
  /// Extracts from assets on first call.
  Future<String> _ensureScriptExtracted() async {
    if (scriptPathOverride != null) return scriptPathOverride!;

    final Directory supportDir = await getApplicationSupportDirectory();
    final String scriptPath = '${supportDir.path}/$_scriptFileName';
    final File scriptFile = File(scriptPath);

    // Always overwrite to stay in sync with bundled version.
    final String scriptContent = await rootBundle.loadString(_scriptAsset);
    await scriptFile.writeAsString(scriptContent);
    return scriptPath;
  }

  /// Cached path to a Python interpreter that has SAM3 available.
  @visibleForTesting
  static String? cachedPythonPath;

  /// Probes common Python interpreters and caches one that can import
  /// [Sam3Predictor] from mlx_vlm.
  @visibleForTesting
  Future<String> findSamPythonForTest() async {
    if (cachedPythonPath != null) return cachedPythonPath!;

    // Candidate interpreters in priority order.
    const List<String> candidates = <String>[
      'python3.11',
      'python3.12',
      'python3.13',
      'python3.10',
      'python3',
    ];

    for (final String candidate in candidates) {
      try {
        final ProcessResult probe = await _processRunner.run(
          candidate,
          <String>[
            '-c',
            'from mlx_vlm.models.sam3.generate import Sam3Predictor',
          ],
        );
        if (probe.exitCode == 0) {
          _logger.info('SAM3-capable Python found: $candidate');
          cachedPythonPath = candidate;
          return candidate;
        }
      } catch (_) {
        // Interpreter not found — try next.
      }
    }

    // Fallback — will likely fail but lets the wrapper report the real error.
    cachedPythonPath = 'python3';
    return 'python3';
  }

  /// Runs SAM3 detection for each object name via the Python wrapper script.
  ///
  /// [vlmBboxes] is an optional list parallel to [objectNames]: each entry is
  /// the VLM-provided bbox `[y1, x1, y2, x2]` (0-1000 normalized) for that
  /// object, or `null` when the VLM supplied none. When present, the wrapper
  /// passes each bbox to SAM3 as a box prompt so detection is guided to the
  /// right region instead of searching the whole image.
  ///
  /// Returns an empty list (triggering VLM-bbox fallback) if the subprocess
  /// fails or Python/mlx_vlm is not installed.
  Future<List<SamDetection>> detectObjects(
    String imagePath,
    List<String> objectNames, {
    List<List<int>?>? vlmBboxes,
    CancelToken? cancelToken,
  }) async {
    final String objectsJson = jsonEncode(objectNames);

    try {
      final String scriptPath = await _ensureScriptExtracted();
      final String python = await findSamPythonForTest();

      final List<String> args = <String>[
        scriptPath,
        '--image',
        imagePath,
        '--objects',
        objectsJson,
      ];
      // Only forward box hints when provided, keeping the call
      // backwards-compatible for callers that have none.
      if (vlmBboxes != null) {
        args.addAll(<String>['--boxes', jsonEncode(vlmBboxes)]);
      }

      final ProcessResult result = await _processRunner.run(
        python,
        args,
        cancelToken: cancelToken,
      );

      if (result.exitCode != 0) {
        _logger.warning(
          'SAM wrapper exited with code ${result.exitCode}: ${result.stderr}',
        );
        return <SamDetection>[];
      }

      final String stdout = result.stdout.toString().trim();
      if (stdout.isEmpty) {
        return <SamDetection>[];
      }

      final List<dynamic> parsed = jsonDecode(stdout) as List<dynamic>;
      return parsed.map((dynamic item) {
        final Map<String, dynamic> map = item as Map<String, dynamic>;
        final List<dynamic>? rawBbox = map['bbox'] as List<dynamic>?;
        return SamDetection(
          name: map['name'] as String,
          bbox: rawBbox?.cast<int>(),
        );
      }).toList();
    } on CancellationException {
      rethrow;
    } catch (e) {
      _logger.warning('SAM detection failed: $e');
      return <SamDetection>[];
    }
  }
}

/// Type of the SAM subprocess entry point [computeSamBboxes] depends on.
/// The repository passes its injected [SamProcessService.detectObjects]
/// through so tests mocking the service keep working.
typedef SamDetectObjects =
    Future<List<SamDetection>> Function(
      String imagePath,
      List<String> objectNames, {
      List<List<int>?>? vlmBboxes,
    });

/// Runs SAM3 detection for the elements of [caption] that have a bbox and
/// are not likely-group elements. Returns a sparse map of
/// `original element index → SAM-refined bbox` in `[y1, x1, y2, x2]`
/// 0-1000 normalized coordinates.
///
/// Mirrors the SAM subset of the full structured pipeline: each eligible
/// element's existing bbox is passed as a box prompt so SAM3 refines the
/// indicated region, and the existing [SamBboxService.matchDetectionsToObjects]
/// greedy matcher decides which SAM detection wins each slot. Slots with no
/// SAM detection fall back to the original (VLM) bbox, so the caller always
/// gets a usable box for elements it asked about.
///
/// [detect] is the caller's SAM detection entry point (usually
/// [SamProcessService.detectObjects]); errors from it are logged and an empty
/// map is returned.
Future<Map<int, List<int>>> computeSamBboxes({
  required File imageFile,
  required IdeogramCaption caption,
  required SamDetectObjects detect,
}) async {
  final SamBboxService samBboxService = SamBboxService();
  final Logger logger = locator<Logger>();
  final List<IdeogramElement> elements =
      caption.compositionalDeconstruction.elements;

  final List<int> eligibleIndices = <int>[];
  final List<String> eligibleNames = <String>[];
  final List<List<int>?> eligibleBboxes = <List<int>?>[];

  for (int i = 0; i < elements.length; i++) {
    final IdeogramElement el = elements[i];
    if (el.bbox == null) continue;
    final String name = samPromptName(el);
    if (name.isEmpty) continue;
    if (samBboxService.isLikelyGroup(name, el.desc)) {
      logger.fine('Skipping SAM for group element: "$name"');
      continue;
    }
    eligibleIndices.add(i);
    eligibleNames.add(name);
    eligibleBboxes.add(el.bbox);
  }

  if (eligibleIndices.isEmpty) {
    return <int, List<int>>{};
  }

  final List<SamDetection> detections;
  try {
    detections = await detect(
      imageFile.path,
      eligibleNames,
      vlmBboxes: eligibleBboxes,
    );
  } catch (e) {
    logger.warning('computeSamBboxes: SAM detection failed: $e');
    return <int, List<int>>{};
  }

  // Match SAM detections back to the eligible subset.
  final List<VlmObjectBboxPair> eligiblePairs = <VlmObjectBboxPair>[];
  for (int j = 0; j < eligibleIndices.length; j++) {
    eligiblePairs.add(
      VlmObjectBboxPair(name: eligibleNames[j], bbox: eligibleBboxes[j]),
    );
  }
  final List<SamDetection> matched = samBboxService.matchDetectionsToObjects(
    detections,
    eligiblePairs,
  );

  final Map<int, List<int>> result = <int, List<int>>{};
  for (int j = 0; j < eligibleIndices.length; j++) {
    final SamDetection det = matched[j];
    if (det.bbox == null) continue;
    result[eligibleIndices[j]] = det.bbox!;
  }
  return result;
}

/// Derives a SAM text-prompt name from an [IdeogramElement].
///
/// [IdeogramElement] has no dedicated `name` field (the production pipeline
/// sources names from the VLM). For the comparison toggle we use the first
/// sentence of `desc`, trimmed. Empty string when nothing usable is there.
String samPromptName(IdeogramElement el) {
  final String s = el.desc.trim();
  if (s.isEmpty) return '';
  return s.split('.').first.trim();
}

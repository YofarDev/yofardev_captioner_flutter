import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/service_locator.dart';
import '../../../captioning/data/services/process_runner.dart';

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

      final ProcessResult result = await _processRunner.run(python, args);

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
    } catch (e) {
      _logger.warning('SAM detection failed: $e');
      return <SamDetection>[];
    }
  }
}

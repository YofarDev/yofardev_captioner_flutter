import 'dart:math';

import 'sam_process_service.dart';

/// Helper to carry VLM object bbox pairs through matching.
class VlmObjectBboxPair {
  const VlmObjectBboxPair({required this.name, this.bbox});

  final String name;
  final List<int>? bbox;
}

/// SAM-detection-to-VLM-object matching and bbox geometry heuristics.
///
/// Pure computation — the repository owns the SAM subprocess
/// ([SamProcessService]) and delegates the greedy matching, IoU gating, and
/// group-element classification here.
class SamBboxService {
  /// IoU threshold below which a SAM detection is considered to have landed
  /// on the wrong region and is rejected in favour of the VLM bbox. SAM is
  /// meant to *refine* the VLM bbox, so a real match overlaps substantially;
  /// a near-zero overlap means SAM segmented a different object.
  static const double _samIouThreshold = 0.1;

  /// Greedy bbox matching between SAM detections and VLM objects.
  ///
  /// Ported from reference repo's sam_detection.py matching logic.
  /// Groups by name, matches by center distance, falls back to VLM bbox.
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
        // IoU gate: reject SAM detections that landed away from the chosen
        // VLM region (e.g. SAM latched onto a different same-text object).
        // A rejected slot falls through to the VLM-bbox fallback below.
        if (_samMatchesVlm(
          samDets[0].bbox,
          vlmObjects[vlmIndices[bestIdx]].bbox,
        )) {
          results[vlmIndices[bestIdx]] = samDets[0];
        }
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
          // IoU gate: skip SAM detections that don't overlap the VLM region.
          if (!_samMatchesVlm(
            samDets[pair.samIdx].bbox,
            vlmObjects[vlmIndices[pair.vlmIdx]].bbox,
          )) {
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

  /// Returns true if the VLM element likely represents a group of items
  /// rather than a single individual object.
  ///
  /// Heuristics:
  /// - Name is explicitly plural (ends in 's' but not 'ss' like "glass")
  /// - Description contains group indicators
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

  /// Returns true if [samBbox] is a plausible refinement of [vlmBbox].
  /// When [vlmBbox] is null there is no spatial hint to validate against,
  /// so the SAM detection is accepted as-is.
  bool _samMatchesVlm(List<int>? samBbox, List<int>? vlmBbox) {
    if (vlmBbox == null) return true;
    return computeIou(samBbox, vlmBbox) >= _samIouThreshold;
  }

  /// Intersection-over-union of two [y1, x1, y2, x2] bboxes in 0-1000
  /// normalized coordinates. Returns 0 for null or malformed input.
  double computeIou(List<int>? a, List<int>? b) {
    if (a == null || b == null || a.length != 4 || b.length != 4) {
      return 0.0;
    }
    final double ay1 = a[0].toDouble();
    final double ax1 = a[1].toDouble();
    final double ay2 = a[2].toDouble();
    final double ax2 = a[3].toDouble();
    final double by1 = b[0].toDouble();
    final double bx1 = b[1].toDouble();
    final double by2 = b[2].toDouble();
    final double bx2 = b[3].toDouble();
    final double interY1 = max(ay1, by1);
    final double interX1 = max(ax1, bx1);
    final double interY2 = min(ay2, by2);
    final double interX2 = min(ax2, bx2);
    final double interH = (interY2 - interY1).clamp(0.0, double.infinity);
    final double interW = (interX2 - interX1).clamp(0.0, double.infinity);
    final double inter = interH * interW;
    final double areaA = (ay2 - ay1) * (ax2 - ax1);
    final double areaB = (by2 - by1) * (bx2 - bx1);
    final double union = areaA + areaB - inter;
    if (union <= 0) return 0.0;
    return inter / union;
  }
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

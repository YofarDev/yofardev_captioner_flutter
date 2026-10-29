import 'dart:math' as math;

/// Port of AI Toolkit's `toolkit/buckets.py::get_bucket_for_image_size`
/// (pinned upstream commit b69b98314557f7c8b08e11bbb14e48d959e6ab26),
/// including `setup_buckets`' scale/crop arithmetic from
/// `toolkit/dataloader_mixins.py`.
///
/// The trainer picks the candidate bucket (multiples of [divisibility])
/// whose pixel count is closest to the target while staying ≤
/// `resolution²`, scales the image by the **max** axis scale factor
/// (so both axes reach at least the bucket size), then centrally crops.
/// Reproducing this exactly is what makes a prepared pair a fixed point:
/// feeding the realized dimensions back through this function yields the
/// same bucket, scale 1, and crop offset 0.
({int width, int height}) aiToolkitBucket({
  required int width,
  required int height,
  required int resolution,
  required int divisibility,
}) {
  final int totalPixels = width * height;
  final int maxPixels = resolution * resolution;
  final int targetPixels = math.min(totalPixels, maxPixels);

  final double scaler = math.sqrt(targetPixels / totalPixels);
  final double wRaw = (width * scaler) / divisibility;
  final double hRaw = (height * scaler) / divisibility;

  final List<(int, int)> candidates = <(int, int)>[
    (
      wRaw.floorToDouble().toInt() * divisibility,
      hRaw.floorToDouble().toInt() * divisibility,
    ),
    (
      wRaw.floorToDouble().toInt() * divisibility,
      hRaw.ceilToDouble().toInt() * divisibility,
    ),
    (
      wRaw.ceilToDouble().toInt() * divisibility,
      hRaw.floorToDouble().toInt() * divisibility,
    ),
    (
      wRaw.ceilToDouble().toInt() * divisibility,
      hRaw.ceilToDouble().toInt() * divisibility,
    ),
  ];
  bool cappedCandidate((int, int) wh) =>
      wh.$1 > 0 && wh.$2 > 0 && wh.$1 * wh.$2 <= maxPixels;
  final List<(int, int)> capped = candidates.where(cappedCandidate).toList();
  final List<(int, int)> effective = capped.isNotEmpty
      ? capped
      : <(int, int)>[
          (
            math.max(divisibility, wRaw.floorToDouble().toInt() * divisibility),
            math.max(divisibility, hRaw.floorToDouble().toInt() * divisibility),
          ),
        ];

  (int, int) best = effective[0];
  for (final (int, int) wh in effective.skip(1)) {
    if ((wh.$1 * wh.$2 - targetPixels).abs() <
        (best.$1 * best.$2 - targetPixels).abs()) {
      best = wh;
    }
  }
  return (width: best.$1, height: best.$2);
}

/// The realized image transform for one source image under the AI Toolkit
/// non-square-crop loader path: uniform scale to
/// `scaleToWidth×scaleToHeight` (ceil of source × max axis factor), then a
/// central crop of `bucketWidth×bucketHeight` at
/// `int((scaleTo − bucket) / 2)`.
class MossImageTransform {
  const MossImageTransform({
    required this.scaleToWidth,
    required this.scaleToHeight,
    required this.cropX,
    required this.cropY,
    required this.bucketWidth,
    required this.bucketHeight,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  /// Realized per-axis scales actually applied by the pixel resize: the
  /// resize targets the independently ceiled scale-to frame, so x and y
  /// scales differ from each other and from the ideal bucket scale by up to
  /// one pixel of rounding. Boxes MUST use these, not a single ideal factor.
  double get scaleFactorX => scaleToWidth / sourceWidth;
  double get scaleFactorY => scaleToHeight / sourceHeight;

  /// Ideal uniform scale (kept for manifest/report purposes only).
  double get scaleFactor {
    final double sx = bucketWidth / sourceWidth;
    final double sy = bucketHeight / sourceHeight;
    return sx > sy ? sx : sy;
  }

  final int sourceWidth;
  final int sourceHeight;
  final int scaleToWidth;
  final int scaleToHeight;
  final int cropX;
  final int cropY;
  final int bucketWidth;
  final int bucketHeight;

  int get outputWidth => bucketWidth;
  int get outputHeight => bucketHeight;
}

/// Computes the trainer-identical transform for [sourceWidth]×
/// [sourceHeight].
MossImageTransform planAiToolkitTransform({
  required int sourceWidth,
  required int sourceHeight,
  required int resolution,
  required int divisibility,
}) {
  final ({int width, int height}) bucket = aiToolkitBucket(
    width: sourceWidth,
    height: sourceHeight,
    resolution: resolution,
    divisibility: divisibility,
  );
  final double scaleX = bucket.width / sourceWidth;
  final double scaleY = bucket.height / sourceHeight;
  final double maxScale = math.max(scaleX, scaleY);
  // Loader: int(math.ceil(width * max_scale_factor)).
  final int scaleToWidth = (sourceWidth * maxScale).ceilToDouble().toInt();
  final int scaleToHeight = (sourceHeight * maxScale).ceilToDouble().toInt();
  return MossImageTransform(
    scaleToWidth: scaleToWidth,
    scaleToHeight: scaleToHeight,
    cropX: (scaleToWidth - bucket.width) ~/ 2,
    cropY: (scaleToHeight - bucket.height) ~/ 2,
    bucketWidth: bucket.width,
    bucketHeight: bucket.height,
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
  );
}

/// Maps one top-left `xyxy` source pixel box through the transform using the
/// **realized per-axis scales** of the actual pixel resize (the loader
/// resizes to the independently ceiled scale-to frame, so x and y scale
/// slightly differently). Rounding happens **once**, at final serialization.
/// Returns null when the box collapses to zero area (dropped, with a
/// diagnostic).
List<int>? transformBbox(List<int> bbox, MossImageTransform transform) {
  final double sx = transform.scaleFactorX;
  final double sy = transform.scaleFactorY;
  final double x1 = bbox[0] * sx - transform.cropX;
  final double y1 = bbox[1] * sy - transform.cropY;
  final double x2 = bbox[2] * sx - transform.cropX;
  final double y2 = bbox[3] * sy - transform.cropY;
  final int ix1 = x1.round().clamp(0, transform.outputWidth);
  final int iy1 = y1.round().clamp(0, transform.outputHeight);
  final int ix2 = x2.round().clamp(0, transform.outputWidth);
  final int iy2 = y2.round().clamp(0, transform.outputHeight);
  if (ix1 >= ix2 || iy1 >= iy2) {
    return null;
  }
  return <int>[ix1, iy1, ix2, iy2];
}

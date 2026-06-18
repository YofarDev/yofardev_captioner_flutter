import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Extracts color palettes from images using k-means clustering in CIELAB space.
///
/// Lab distance approximates human color perception much better than raw RGB
/// distance, producing more visually distinct and accurate palettes.
class ColorExtractionService {
  /// Extracts a palette of [colorCount] hex colors from [imageFile].
  ///
  /// Returns colors as "#RRGGBB" strings, sorted by dominance (largest cluster first).
  Future<List<String>> extractPalette(
    File imageFile, {
    int colorCount = 6,
  }) async {
    final Uint8List bytes = await imageFile.readAsBytes();
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return <String>[];
    }
    if (image == null) return <String>[];

    final img.Image rgb = _normalizeToRgb(image);
    final List<_Lab> labPixels = _samplePixelsAsLab(rgb);
    if (labPixels.isEmpty) return <String>[];

    final List<_Lab> centroids = _kMeansLab(labPixels, colorCount);
    return _centroidsToHex(centroids);
  }

  /// Normalizes a decoded image to 3-channel RGB.
  ///
  /// Grayscale / palettized / single-channel PNGs decode with numChannels < 3,
  /// where only [Pixel.r] holds the value while g/b read as 0 — turning every
  /// gray pixel into pure red (255,0,0). Converting to 3 channels resolves the
  /// luminance into a proper RGB triplet and dereferences palette indices.
  img.Image _normalizeToRgb(img.Image image) {
    if (image.numChannels >= 3) return image;
    return image.convert(numChannels: 3);
  }

  /// Snap low-chroma centroids to pure gray before output.
  ///
  /// In near-grayscale images, JPEG chroma noise makes k-means++ seed on tinted
  /// outliers, producing spurious reds/blues. Centroids below [grayChromaThreshold]
  /// Lab chroma get their a/b forced to 0 so output hex stays neutral.
  List<String> _centroidsToHex(
    List<_Lab> centroids, {
    double grayChromaThreshold = 4.0,
  }) {
    return centroids.map((_Lab c) {
      final double chroma = sqrt(c.a * c.a + c.b * c.b);
      final _Lab cleaned = chroma < grayChromaThreshold ? _Lab(c.l, 0, 0) : c;
      return _labToRgb(cleaned).toHex();
    }).toList();
  }

  /// Extracts a palette from a cropped region defined by [bbox].
  ///
  /// [bbox] is [y1, x1, y2, x2] in 0-1000 normalized coordinates.
  Future<List<String>> extractPaletteFromRegion(
    File imageFile,
    List<int> bbox, {
    int colorCount = 5,
  }) async {
    final Uint8List bytes = await imageFile.readAsBytes();
    img.Image? fullImage;
    try {
      fullImage = img.decodeImage(bytes);
    } catch (_) {
      return <String>[];
    }
    if (fullImage == null) return <String>[];

    final img.Image rgb = _normalizeToRgb(fullImage);

    final int imgW = rgb.width;
    final int imgH = rgb.height;

    // Convert 0-1000 normalized bbox to pixel coordinates.
    final int px1 = (bbox[1] / 1000 * imgW).round().clamp(0, imgW - 1);
    final int py1 = (bbox[0] / 1000 * imgH).round().clamp(0, imgH - 1);
    final int px2 = (bbox[3] / 1000 * imgW).round().clamp(0, imgW);
    final int py2 = (bbox[2] / 1000 * imgH).round().clamp(0, imgH);

    if (px2 <= px1 || py2 <= py1) return <String>[];

    final img.Image region = img.copyCrop(
      rgb,
      x: px1,
      y: py1,
      width: px2 - px1,
      height: py2 - py1,
    );

    final List<_Lab> labPixels = _samplePixelsAsLab(region);
    if (labPixels.isEmpty) return <String>[];

    final List<_Lab> centroids = _kMeansLab(labPixels, colorCount);
    return _centroidsToHex(centroids);
  }

  /// Returns the "#RRGGBB" hex string of the pixel at ([x], [y]) in [image].
  ///
  /// Reuses [_normalizeToRgb] so grayscale / palettized images read as a proper
  /// RGB triplet instead of (luminance, 0, 0). Coordinates are clamped to the
  /// image bounds so callers can pass raw (possibly off-edge) pointer math.
  ///
  /// Alpha is ignored; output is always opaque RGB.
  String hexAt(img.Image image, int x, int y) {
    final img.Image rgb = _normalizeToRgb(image);
    final int px = x.clamp(0, rgb.width - 1);
    final int py = y.clamp(0, rgb.height - 1);
    final img.Pixel pixel = rgb.getPixel(px, py);
    return _Rgb(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()).toHex();
  }

  // ===========================================================================
  // Pixel sampling
  // ===========================================================================

  /// Samples pixels from an image, skipping every Nth pixel for performance.
  /// Converts directly to Lab space and snaps near-gray pixels onto the neutral
  /// axis to suppress JPEG chroma noise.
  ///
  /// Grayscale images stored as RGB JPEGs carry residual color in their chroma
  /// channels (chroma subsampling, decode dithering). k-means++ deliberately
  /// seeds on the farthest points, so without cleaning these tinted pixels would
  /// become centroids and report spurious reds/blues. Pixels whose Lab chroma
  /// [√(a²+b²)] is below [grayChromaThreshold] get a/b forced to 0.
  List<_Lab> _samplePixelsAsLab(
    img.Image image, {
    double grayChromaThreshold = 8.0,
  }) {
    final int total = image.width * image.height;
    final int step = max(1, total ~/ 5000);
    final List<_Lab> pixels = <_Lab>[];

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if ((y * image.width + x) % step != 0) continue;
        final img.Pixel pixel = image.getPixel(x, y);
        if (pixel.a < 128) continue;
        final _Lab lab = _rgbToLab(
          _Rgb(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()),
        );
        final double chroma = sqrt(lab.a * lab.a + lab.b * lab.b);
        pixels.add(chroma < grayChromaThreshold ? _Lab(lab.l, 0, 0) : lab);
      }
    }
    return pixels;
  }

  // ===========================================================================
  // K-means in Lab space
  // ===========================================================================

  /// K-means clustering in CIELAB space with k-means++ initialization.
  /// Returns cluster centroids sorted by cluster size (largest first).
  List<_Lab> _kMeansLab(List<_Lab> pixels, int k, {int maxIterations = 20}) {
    if (pixels.length <= k) return pixels.take(k).toList();

    final Random random = Random(42);
    final List<_Lab> centroids = _kMeansPlusPlusInitLab(pixels, k, random);
    final List<int> assignments = List<int>.filled(pixels.length, 0);

    for (int iter = 0; iter < maxIterations; iter++) {
      // Assign each pixel to nearest centroid.
      for (int i = 0; i < pixels.length; i++) {
        int nearest = 0;
        double minDist = double.infinity;
        for (int c = 0; c < centroids.length; c++) {
          final double d = pixels[i].distanceSq(centroids[c]);
          if (d < minDist) {
            minDist = d;
            nearest = c;
          }
        }
        assignments[i] = nearest;
      }

      // Recompute centroids.
      final List<_Lab> newCentroids = <_Lab>[];
      for (int c = 0; c < centroids.length; c++) {
        double sumL = 0;
        double sumA = 0;
        double sumB = 0;
        int count = 0;
        for (int i = 0; i < pixels.length; i++) {
          if (assignments[i] == c) {
            sumL += pixels[i].l;
            sumA += pixels[i].a;
            sumB += pixels[i].b;
            count++;
          }
        }
        if (count > 0) {
          newCentroids.add(_Lab(sumL / count, sumA / count, sumB / count));
        } else {
          // Dead cluster — reinitialize to random pixel.
          newCentroids.add(pixels[random.nextInt(pixels.length)]);
        }
      }

      // Check convergence.
      bool converged = true;
      for (int c = 0; c < centroids.length; c++) {
        if (centroids[c].distanceSq(newCentroids[c]) > 0.01) {
          converged = false;
          break;
        }
      }
      for (int c = 0; c < centroids.length; c++) {
        centroids[c] = newCentroids[c];
      }
      if (converged) break;
    }

    // Sort by cluster size (largest first).
    final List<int> counts = List<int>.filled(centroids.length, 0);
    for (final int a in assignments) {
      counts[a]++;
    }
    final List<int> indices = List<int>.generate(centroids.length, (int i) => i)
      ..sort((int a, int b) => counts[b].compareTo(counts[a]));

    return indices.map((int i) => centroids[i]).toList();
  }

  /// K-means++ initialization in Lab space.
  List<_Lab> _kMeansPlusPlusInitLab(List<_Lab> pixels, int k, Random random) {
    final List<_Lab> centroids = <_Lab>[];
    centroids.add(pixels[random.nextInt(pixels.length)]);

    for (int c = 1; c < k; c++) {
      final List<double> distances = pixels
          .map(
            (_Lab p) => centroids
                .map((_Lab center) => p.distanceSq(center))
                .reduce(min),
          )
          .toList();
      final double totalDist = distances.reduce((double a, double b) => a + b);
      if (totalDist == 0) {
        centroids.add(pixels[random.nextInt(pixels.length)]);
        continue;
      }

      final double target = random.nextDouble() * totalDist;
      double cumulative = 0;
      int idx = 0;
      for (int j = 0; j < distances.length; j++) {
        cumulative += distances[j];
        if (cumulative >= target) {
          idx = j;
          break;
        }
      }
      centroids.add(pixels[idx]);
    }
    return centroids;
  }

  // ===========================================================================
  // Color space conversions
  // ===========================================================================

  /// sRGB channel (0-255) → linear.
  static double _srgbToLinear(int c) {
    final double s = c / 255.0;
    return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Linear → sRGB byte (0-255).
  static int _linearToSrgb(double c) {
    final double s = c <= 0.0031308
        ? c * 12.92
        : 1.055 * pow(c, 1.0 / 2.4).toDouble() - 0.055;
    return (s.clamp(0.0, 1.0) * 255.0).round();
  }

  static const double _labEpsilon = 0.008856; // (6/29)^3
  static const double _labKappa = 903.3; // (29/3)^3

  /// sRGB → CIELAB (D65 illuminant).
  static _Lab _rgbToLab(_Rgb rgb) {
    final double lr = _srgbToLinear(rgb.r);
    final double lg = _srgbToLinear(rgb.g);
    final double lb = _srgbToLinear(rgb.b);

    // Linear RGB → XYZ (D65).
    final double x = 0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb;
    final double y = 0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb;
    final double z = 0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb;

    // XYZ normalized to D65 white point.
    double fx = x / 0.95047;
    double fy = y / 1.00000;
    double fz = z / 1.08883;

    fx = fx > _labEpsilon
        ? pow(fx, 1.0 / 3.0).toDouble()
        : (_labKappa * fx + 16.0) / 116.0;
    fy = fy > _labEpsilon
        ? pow(fy, 1.0 / 3.0).toDouble()
        : (_labKappa * fy + 16.0) / 116.0;
    fz = fz > _labEpsilon
        ? pow(fz, 1.0 / 3.0).toDouble()
        : (_labKappa * fz + 16.0) / 116.0;

    return _Lab(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz));
  }

  /// CIELAB → sRGB.
  static _Rgb _labToRgb(_Lab lab) {
    final double fy = (lab.l + 16.0) / 116.0;
    final double fx = lab.a / 500.0 + fy;
    final double fz = fy - lab.b / 200.0;

    final double xr = fx * fx * fx > _labEpsilon
        ? fx * fx * fx
        : (116.0 * fx - 16.0) / _labKappa;
    final double yr = lab.l > _labKappa * _labEpsilon
        ? pow((lab.l + 16.0) / 116.0, 3.0).toDouble()
        : lab.l / _labKappa;
    final double zr = fz * fz * fz > _labEpsilon
        ? fz * fz * fz
        : (116.0 * fz - 16.0) / _labKappa;

    // Denormalize from D65 white point (xr,yr,zr are X/Xn, Y/Yn, Z/Zn — the
    // forward transform divided by these, so the inverse must multiply back).
    final double x = xr * 0.95047;
    final double y = yr * 1.00000;
    final double z = zr * 1.08883;

    // XYZ → linear RGB (D65).
    final double lr = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z;
    final double lg = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
    final double lb = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z;

    return _Rgb(_linearToSrgb(lr), _linearToSrgb(lg), _linearToSrgb(lb));
  }
}

// =============================================================================
// Internal data classes
// =============================================================================

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  String toHex() =>
      '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

class _Lab {
  const _Lab(this.l, this.a, this.b);

  final double l;
  final double a;
  final double b;

  double distanceSq(_Lab other) {
    final double dl = l - other.l;
    final double da = a - other.a;
    final double db = b - other.b;
    return dl * dl + da * da + db * db;
  }
}

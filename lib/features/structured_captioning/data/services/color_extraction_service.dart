import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Extracts color palettes from images using k-means clustering on pixel data.
class ColorExtractionService {
  /// Extracts a palette of [colorCount] hex colors from [imageFile].
  ///
  /// Returns colors as "#RRGGBB" strings.
  Future<List<String>> extractPalette(
    File imageFile, {
    int colorCount = 6,
  }) async {
    final Uint8List bytes = await imageFile.readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return <String>[];

    final List<_Rgb> pixels = _samplePixels(image);
    if (pixels.isEmpty) return <String>[];

    final List<_Rgb> centroids = _kMeansCluster(pixels, colorCount);
    return centroids.map((_Rgb c) => '#${c.toHex()}').toList();
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
    final img.Image? fullImage = img.decodeImage(bytes);
    if (fullImage == null) return <String>[];

    final int imgW = fullImage.width;
    final int imgH = fullImage.height;

    // Convert 0-1000 normalized bbox to pixel coordinates.
    final int px1 = (bbox[1] / 1000 * imgW).round().clamp(0, imgW - 1);
    final int py1 = (bbox[0] / 1000 * imgH).round().clamp(0, imgH - 1);
    final int px2 = (bbox[3] / 1000 * imgW).round().clamp(0, imgW);
    final int py2 = (bbox[2] / 1000 * imgH).round().clamp(0, imgH);

    if (px2 <= px1 || py2 <= py1) return <String>[];

    final img.Image region = img.copyCrop(
      fullImage,
      x: px1,
      y: py1,
      width: px2 - px1,
      height: py2 - py1,
    );

    final List<_Rgb> pixels = _samplePixels(region);
    if (pixels.isEmpty) return <String>[];

    final List<_Rgb> centroids = _kMeansCluster(pixels, colorCount);
    return centroids.map((_Rgb c) => '#${c.toHex()}').toList();
  }

  /// Samples pixels from an image, skipping every Nth pixel for performance.
  List<_Rgb> _samplePixels(img.Image image) {
    final int total = image.width * image.height;
    // Target ~5000 pixels for clustering.
    final int step = max(1, total ~/ 5000);
    final List<_Rgb> pixels = <_Rgb>[];

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if ((y * image.width + x) % step != 0) continue;
        final img.Pixel pixel = image.getPixel(x, y);
        // Skip mostly transparent pixels.
        if (pixel.a < 128) continue;
        pixels.add(_Rgb(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()));
      }
    }
    return pixels;
  }

  /// K-means clustering on RGB pixel data.
  ///
  /// Uses k-means++ initialization and runs [maxIterations] refinement steps.
  /// Returns cluster centroids sorted by cluster size (largest first).
  List<_Rgb> _kMeansCluster(
    List<_Rgb> pixels,
    int k, {
    int maxIterations = 12,
  }) {
    if (pixels.length <= k) {
      return pixels.take(k).toList();
    }

    final Random random = Random(42);
    final List<_Rgb> centroids = _kMeansPlusPlusInit(pixels, k, random);
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
      final List<_Rgb> newCentroids = <_Rgb>[];
      for (int c = 0; c < centroids.length; c++) {
        int sumR = 0;
        int sumG = 0;
        int sumB = 0;
        int count = 0;
        for (int i = 0; i < pixels.length; i++) {
          if (assignments[i] == c) {
            sumR += pixels[i].r;
            sumG += pixels[i].g;
            sumB += pixels[i].b;
            count++;
          }
        }
        if (count > 0) {
          newCentroids.add(_Rgb(sumR ~/ count, sumG ~/ count, sumB ~/ count));
        } else {
          // Dead cluster — reinitialize to random pixel.
          newCentroids.add(pixels[random.nextInt(pixels.length)]);
        }
      }

      // Check convergence.
      bool converged = true;
      for (int c = 0; c < centroids.length; c++) {
        if (centroids[c].distanceSq(newCentroids[c]) > 1.0) {
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

  /// K-means++ initialization: spread initial centroids across the data.
  List<_Rgb> _kMeansPlusPlusInit(List<_Rgb> pixels, int k, Random random) {
    final List<_Rgb> centroids = <_Rgb>[];
    centroids.add(pixels[random.nextInt(pixels.length)]);

    for (int c = 1; c < k; c++) {
      final List<double> distances = pixels
          .map(
            (_Rgb p) => centroids
                .map((_Rgb center) => p.distanceSq(center))
                .reduce(min),
          )
          .toList();
      final double totalDist = distances.reduce((double a, double b) => a + b);
      if (totalDist == 0) {
        centroids.add(pixels[random.nextInt(pixels.length)]);
        continue;
      }

      final double target = random.nextDouble() * totalDist;
      int idx = 0;
      double cumulative = 0;
      while (idx < distances.length - 1 && cumulative < target) {
        cumulative += distances[idx];
        idx++;
      }
      centroids.add(pixels[idx]);
    }
    return centroids;
  }
}

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  double distanceSq(_Rgb other) {
    final int dr = r - other.r;
    final int dg = g - other.g;
    final int db = b - other.b;
    return (dr * dr + dg * dg + db * db).toDouble();
  }

  String toHex() =>
      '${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

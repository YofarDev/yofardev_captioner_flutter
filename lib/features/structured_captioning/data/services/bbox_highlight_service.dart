import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// Renders an image with a target bbox drawn as a magenta highlight, for use
/// as the VLM payload in single-element recaptioning (Approach C in the design
/// doc): the whole image is sent with the target box visually marked so the
/// VLM doesn't have to map numeric coords to pixels.
class BboxHighlightService {
  BboxHighlightService();

  static const int _maxDimension = 1024;
  static const int _maxFileSize = 1 * 1024 * 1024; // 1 MB

  final Logger _logger = Logger('BboxHighlightService');

  /// Renders [imageFile] with [bbox] drawn on it, resized so the longest side
  /// is <= 1024px and the JPEG is <= 1 MB.
  ///
  /// [bbox] is `[y1, x1, y2, x2]` in 0-1000 normalized coordinates.
  ///
  /// Returns the absolute path to a temp JPEG. Caller must pass the path to
  /// [cleanup] when done.
  ///
  /// Throws [ArgumentError] if [bbox] does not have exactly 4 entries or
  /// represents a zero-area region.
  Future<String> renderHighlightedJpeg(File imageFile, List<int> bbox) async {
    if (bbox.length != 4) {
      throw ArgumentError('bbox must have exactly 4 entries [y1,x1,y2,x2]');
    }
    if ((bbox[2] - bbox[0]) <= 0 || (bbox[3] - bbox[1]) <= 0) {
      throw ArgumentError('bbox has zero or negative area');
    }

    final Uint8List bytes = await imageFile.readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image: ${imageFile.path}');
    }

    // Downscale if needed (keep aspect ratio).
    img.Image work = decoded;
    final int longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longest > _maxDimension) {
      final double scale = _maxDimension / longest;
      work = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
      );
    }

    final int imgW = work.width;
    final int imgH = work.height;

    // Convert 0-1000 normalized bbox -> pixels on the (possibly resized)
    // image. Same math as color_extraction_service.dart.
    final int y1 = (bbox[0] / 1000 * imgH).round().clamp(0, imgH - 1);
    final int x1 = (bbox[1] / 1000 * imgW).round().clamp(0, imgW - 1);
    final int y2 = (bbox[2] / 1000 * imgH).round().clamp(y1 + 1, imgH);
    final int x2 = (bbox[3] / 1000 * imgW).round().clamp(x1 + 1, imgW);

    final int thickness = (imgW / 200).clamp(2, 8).toInt();

    // Translucent magenta fill, then white outline, then magenta outline.
    final img.Color magenta = img.ColorRgba8(255, 0, 255, 70);
    final img.Color white = img.ColorRgb8(255, 255, 255);
    final img.Color magentaSolid = img.ColorRgb8(255, 0, 255);

    img.fillRect(work, x1: x1, y1: y1, x2: x2, y2: y2, color: magenta);
    img.drawRect(
      work,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: white,
      thickness: thickness + 2,
    );
    img.drawRect(
      work,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: magentaSolid,
      thickness: thickness,
    );

    // Corner ticks (L-shaped marks) to disambiguate from neighbors.
    _drawCornerTicks(
      work,
      x1,
      y1,
      x2,
      y2,
      magentaSolid,
      thickness + 4,
      imgW,
      imgH,
    );

    // Encode JPEG, shrinking quality until under the size limit.
    Uint8List encoded = img.encodeJpg(work, quality: 90);
    int quality = 90;
    while (encoded.length > _maxFileSize && quality > 20) {
      quality -= 10;
      encoded = img.encodeJpg(work, quality: quality);
    }

    final Directory tempDir = Directory.systemTemp;
    final String outPath = p.join(
      tempDir.path,
      'bbox_highlight_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}.jpg',
    );
    final File outFile = File(outPath);
    await outFile.writeAsBytes(encoded);
    _logger.fine('Wrote highlighted JPEG to $outPath (${encoded.length} B)');
    return outPath;
  }

  void _drawCornerTicks(
    img.Image image,
    int x1,
    int y1,
    int x2,
    int y2,
    img.Color color,
    int len,
    int imgW,
    int imgH,
  ) {
    final int cl = len.clamp(4, (imgW * 0.1).toInt());
    // Top-left
    img.drawLine(
      image,
      x1: x1,
      y1: y1,
      x2: (x1 + cl).clamp(0, imgW - 1),
      y2: y1,
      color: color,
      thickness: 2,
    );
    img.drawLine(
      image,
      x1: x1,
      y1: y1,
      x2: x1,
      y2: (y1 + cl).clamp(0, imgH - 1),
      color: color,
      thickness: 2,
    );
    // Top-right
    img.drawLine(
      image,
      x1: x2,
      y1: y1,
      x2: (x2 - cl).clamp(0, imgW - 1),
      y2: y1,
      color: color,
      thickness: 2,
    );
    img.drawLine(
      image,
      x1: x2,
      y1: y1,
      x2: x2,
      y2: (y1 + cl).clamp(0, imgH - 1),
      color: color,
      thickness: 2,
    );
    // Bottom-left
    img.drawLine(
      image,
      x1: x1,
      y1: y2,
      x2: (x1 + cl).clamp(0, imgW - 1),
      y2: y2,
      color: color,
      thickness: 2,
    );
    img.drawLine(
      image,
      x1: x1,
      y1: y2,
      x2: x1,
      y2: (y2 - cl).clamp(0, imgH - 1),
      color: color,
      thickness: 2,
    );
    // Bottom-right
    img.drawLine(
      image,
      x1: x2,
      y1: y2,
      x2: (x2 - cl).clamp(0, imgW - 1),
      y2: y2,
      color: color,
      thickness: 2,
    );
    img.drawLine(
      image,
      x1: x2,
      y1: y2,
      x2: x2,
      y2: (y2 - cl).clamp(0, imgH - 1),
      color: color,
      thickness: 2,
    );
  }

  /// Renders a JPEG cropped to [bbox] (instead of highlighting the full image).
  ///
  /// Same downscale and size limits as [renderHighlightedJpeg].
  Future<String> renderCroppedJpeg(File imageFile, List<int> bbox) async {
    if (bbox.length != 4) {
      throw ArgumentError('bbox must have exactly 4 entries [y1,x1,y2,x2]');
    }
    if ((bbox[2] - bbox[0]) <= 0 || (bbox[3] - bbox[1]) <= 0) {
      throw ArgumentError('bbox has zero or negative area');
    }

    final Uint8List bytes = await imageFile.readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image: ${imageFile.path}');
    }

    final int imgW = decoded.width;
    final int imgH = decoded.height;

    final int y1 = (bbox[0] / 1000 * imgH).round().clamp(0, imgH - 1);
    final int x1 = (bbox[1] / 1000 * imgW).round().clamp(0, imgW - 1);
    final int y2 = (bbox[2] / 1000 * imgH).round().clamp(y1 + 1, imgH);
    final int x2 = (bbox[3] / 1000 * imgW).round().clamp(x1 + 1, imgW);

    img.Image cropped = img.copyCrop(decoded, x: x1, y: y1, width: x2 - x1, height: y2 - y1);

    // Downscale if needed.
    if (cropped.width > _maxDimension || cropped.height > _maxDimension) {
      final double scale = _maxDimension /
          (cropped.width > cropped.height ? cropped.width : cropped.height);
      cropped = img.copyResize(
        cropped,
        width: (cropped.width * scale).round(),
        height: (cropped.height * scale).round(),
      );
    }

    Uint8List encoded = img.encodeJpg(cropped, quality: 90);
    int quality = 90;
    while (encoded.length > _maxFileSize && quality > 20) {
      quality -= 10;
      encoded = img.encodeJpg(cropped, quality: quality);
    }

    final Directory tempDir = Directory.systemTemp;
    final String outPath = p.join(
      tempDir.path,
      'bbox_crop_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 32)}.jpg',
    );
    final File outFile = File(outPath);
    await outFile.writeAsBytes(encoded);
    _logger.fine('Wrote cropped JPEG to $outPath (${encoded.length} B)');
    return outPath;
  }

  /// Deletes the temp file produced by [renderHighlightedJpeg]. Safe to call
  /// multiple times; ignores missing files.
  Future<void> cleanup(String path) async {
    final File f = File(path);
    if (f.existsSync()) {
      try {
        await f.delete();
      } catch (e) {
        _logger.warning('Failed to delete temp file $path: $e');
      }
    }
  }
}

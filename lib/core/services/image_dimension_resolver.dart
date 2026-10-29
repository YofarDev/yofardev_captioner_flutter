import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import '../utils/image_header_parser.dart';

/// Exact decoded (and EXIF-oriented) pixel dimensions of an image.
class ImageDimensions {
  const ImageDimensions({required this.width, required this.height});

  final int width;
  final int height;

  @override
  String toString() => '${width}x$height';
}

/// Resolves the *exact* pixel dimensions of an image file.
///
/// PNG/WebP use the header fast path (their headers are orientation-free).
/// JPEG **always** takes the full-decode path with EXIF orientation baked
/// in: raw header dimensions are the *stored* sensor frame, not the display
/// frame, so a rotated JPEG would report swapped width/height. Other unknown
/// headers fall back to the oriented decode too. Returns null only when
/// neither path can establish real dimensions — callers must fail visibly
/// rather than invent a frame.
class ImageDimensionResolver {
  const ImageDimensionResolver();

  Future<ImageDimensions?> resolve(File file) async {
    final bool isJpeg = await _isJpeg(file);
    if (!isJpeg) {
      final ImageHeader? header = await ImageHeaderParser.parseFile(file);
      if (header != null) {
        return ImageDimensions(width: header.width, height: header.height);
      }
    }
    // JPEG (orientation-sensitive) or unknown header: decode and bake.
    final Map<String, int>? dims = await Isolate.run<Map<String, int>?>(
      () => _decodeDimensions(file),
    );
    if (dims == null) {
      return null;
    }
    return ImageDimensions(width: dims['width']!, height: dims['height']!);
  }

  static Future<bool> _isJpeg(File file) async {
    try {
      final RandomAccessFile raf = await file.open();
      try {
        final int length = await raf.length();
        final int read = length < 2 ? length : 2;
        final Uint8List buffer = Uint8List(read);
        await raf.readInto(buffer, 0, read);
        return buffer.length >= 2 && buffer[0] == 0xFF && buffer[1] == 0xD8;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }
}

/// Runs on the background isolate: full decode + orientation bake.
Map<String, int>? _decodeDimensions(File file) {
  final Uint8List bytes;
  try {
    bytes = file.readAsBytesSync();
  } catch (_) {
    return null;
  }
  final img.Decoder? decoder = img.findDecoderForData(bytes);
  if (decoder == null) {
    return null;
  }
  final img.Image? decoded = decoder.decode(bytes);
  if (decoded == null) {
    return null;
  }
  final img.Image baked = img.bakeOrientation(decoded);
  if (baked.width <= 0 || baked.height <= 0) {
    return null;
  }
  return <String, int>{'width': baked.width, 'height': baked.height};
}

/// Function surface for tests/domain code that must not depend on dart:io
/// decoding internals.
typedef ImageDimensionLookup = Future<ImageDimensions?> Function(File file);

/// Default [ImageDimensionLookup] bound to [ImageDimensionResolver.resolve].
Future<ImageDimensions?> defaultDimensionLookup(File file) =>
    const ImageDimensionResolver().resolve(file);

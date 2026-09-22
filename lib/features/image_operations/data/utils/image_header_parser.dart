import 'dart:io';
import 'dart:typed_data';

/// Width/height of an image, read from its header without pixel decoding.
class ImageHeader {
  const ImageHeader({required this.width, required this.height});

  final int width;
  final int height;
}

/// Parses image dimensions from file headers only (PNG, JPEG, WebP).
///
/// This exists so dimension lookups never pay for a full pixel decode:
/// the app resolves dimensions for every image in a folder on load, and
/// both bbox canvases resolve dimensions before painting overlays.
class ImageHeaderParser {
  /// First read size: covers PNG/WebP headers and typical JPEG SOF markers.
  static const int _initialReadBytes = 32 * 1024;

  /// Retry cap for JPEGs whose SOF marker sits past EXIF/thumbnail data.
  static const int _maxReadBytes = 512 * 1024;

  /// Reads a bounded prefix of [file] and parses its header.
  ///
  /// Returns null when the format is unknown or the header is malformed —
  /// callers should fall back to a full decode in that case.
  static Future<ImageHeader?> parseFile(File file) async {
    try {
      final RandomAccessFile raf = await file.open();
      try {
        final int fileLength = await raf.length();
        int readLength = fileLength < _initialReadBytes
            ? fileLength
            : _initialReadBytes;
        Uint8List bytes = await _read(raf, readLength);
        final ImageHeader? header = parse(bytes);
        if (header != null) {
          return header;
        }
        // A JPEG whose SOF marker lies beyond the first chunk (large EXIF)
        // is the only realistic retry case; other formats fail regardless
        // of more bytes.
        if (_looksLikeJpeg(bytes) &&
            fileLength > readLength &&
            readLength < _maxReadBytes) {
          readLength = fileLength < _maxReadBytes ? fileLength : _maxReadBytes;
          await raf.setPosition(0);
          bytes = await _read(raf, readLength);
          return parse(bytes);
        }
        return null;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _read(RandomAccessFile raf, int length) async {
    final Uint8List buffer = Uint8List(length);
    int total = 0;
    while (total < length) {
      final int read = await raf.readInto(buffer, total, length);
      if (read <= 0) {
        break;
      }
      total += read;
    }
    if (total == length) {
      return buffer;
    }
    final Uint8List trimmed = Uint8List(total);
    trimmed.setRange(0, total, buffer);
    return trimmed;
  }

  /// Parses dimensions from an in-memory image header.
  ///
  /// Supports PNG, JPEG (baseline and progressive), and WebP
  /// (lossy, lossless, and extended/VP8X containers).
  static ImageHeader? parse(Uint8List bytes) {
    if (bytes.length < 16) {
      return null;
    }
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return _parsePng(bytes);
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return _parseJpeg(bytes);
    }
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
        bytes[3] == 0x46 && bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) {
      return _parseWebP(bytes);
    }
    return null;
  }

  static bool _looksLikeJpeg(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  static ImageHeader? _parsePng(Uint8List bytes) {
    // IHDR must be the first chunk: signature (8) + length (4) + 'IHDR'.
    if (bytes.length < 24 ||
        bytes[12] != 0x49 ||
        bytes[13] != 0x48 ||
        bytes[14] != 0x44 ||
        bytes[15] != 0x52) {
      return null;
    }
    final int width = (bytes[16] << 24) |
        (bytes[17] << 16) |
        (bytes[18] << 8) |
        bytes[19];
    final int height = (bytes[20] << 24) |
        (bytes[21] << 16) |
        (bytes[22] << 8) |
        bytes[23];
    if (width <= 0 || height <= 0) {
      return null;
    }
    return ImageHeader(width: width, height: height);
  }

  static ImageHeader? _parseJpeg(Uint8List bytes) {
    // Standalone markers carry no length payload.
    bool isStandalone(int marker) =>
        marker == 0xD8 ||
        marker == 0x01 ||
        (marker >= 0xD0 && marker <= 0xD7);

    // SOF0..SOF15 except DHT (C4), JPG (C8), and DAC (CC).
    bool isStartOfFrame(int marker) =>
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;

    int i = 2;
    while (i + 1 < bytes.length) {
      if (bytes[i] != 0xFF) {
        return null;
      }
      // Skip fill bytes before the marker code.
      while (i < bytes.length && bytes[i] == 0xFF) {
        i++;
      }
      if (i >= bytes.length) {
        return null;
      }
      final int marker = bytes[i];
      i++;
      if (isStandalone(marker)) {
        continue;
      }
      if (i + 2 > bytes.length) {
        return null;
      }
      final int segmentLength = (bytes[i] << 8) | bytes[i + 1];
      if (segmentLength < 2) {
        return null;
      }
      if (isStartOfFrame(marker)) {
        // Segment: length (2), precision (1), height (2), width (2).
        if (i + 7 > bytes.length) {
          return null;
        }
        final int height = (bytes[i + 3] << 8) | bytes[i + 4];
        final int width = (bytes[i + 5] << 8) | bytes[i + 6];
        if (width <= 0 || height <= 0) {
          return null;
        }
        return ImageHeader(width: width, height: height);
      }
      i += segmentLength;
    }
    return null;
  }

  static ImageHeader? _parseWebP(Uint8List bytes) {
    // RIFF header (12) then first chunk: fourcc (4) + size (4).
    if (bytes.length < 20) {
      return null;
    }
    final String fourcc = String.fromCharCodes(bytes.sublist(12, 16));

    int le16(int offset) => bytes[offset] | (bytes[offset + 1] << 8);

    int le24(int offset) =>
        bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);

    if (fourcc == 'VP8X') {
      // Flags (4) then canvas size minus one, 3 bytes each.
      if (bytes.length < 30) {
        return null;
      }
      final int width = le24(24) + 1;
      final int height = le24(27) + 1;
      if (width <= 0 || height <= 0) {
        return null;
      }
      return ImageHeader(width: width, height: height);
    }
    if (fourcc == 'VP8 ') {
      // Keyframe: frame tag (3), sync code 9D 01 2A (3), then dims.
      if (bytes.length < 30 ||
          bytes[23] != 0x9D ||
          bytes[24] != 0x01 ||
          bytes[25] != 0x2A) {
        return null;
      }
      final int width = le16(26) & 0x3FFF;
      final int height = le16(28) & 0x3FFF;
      if (width <= 0 || height <= 0) {
        return null;
      }
      return ImageHeader(width: width, height: height);
    }
    if (fourcc == 'VP8L') {
      // Signature 0x2F then 14-bit width-1/height-1 packed into 4 bytes LE.
      if (bytes.length < 25 || bytes[20] != 0x2F) {
        return null;
      }
      final int bits = bytes[21] |
          (bytes[22] << 8) |
          (bytes[23] << 16) |
          (bytes[24] << 24);
      final int width = (bits & 0x3FFF) + 1;
      final int height = ((bits >> 14) & 0x3FFF) + 1;
      if (width <= 0 || height <= 0) {
        return null;
      }
      return ImageHeader(width: width, height: height);
    }
    return null;
  }
}

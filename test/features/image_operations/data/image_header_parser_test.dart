import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yofardev_captioner/features/image_operations/data/utils/image_header_parser.dart';

void main() {
  group('ImageHeaderParser.parse', () {
    group('PNG', () {
      test('reads IHDR dimensions', () {
        final Uint8List png = _buildPng(1920, 1080);
        final ImageHeader? header = ImageHeaderParser.parse(png);
        expect(header, isNotNull);
        expect(header!.width, 1920);
        expect(header.height, 1080);
      });

      test('reads odd dimensions', () {
        final Uint8List png = _buildPng(1023, 767);
        final ImageHeader? header = ImageHeaderParser.parse(png);
        expect(header!.width, 1023);
        expect(header.height, 767);
      });

      test('rejects PNG without IHDR as first chunk', () {
        final Uint8List bytes = Uint8List.fromList(<int>[
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0, 0, 0, 13, // chunk length
          0x74, 0x45, 0x58, 0x74, // 'tEXt' instead of 'IHDR'
          ...List<int>.filled(13, 0),
        ]);
        expect(ImageHeaderParser.parse(bytes), isNull);
      });
    });

    group('JPEG', () {
      test('reads SOF0 dimensions after APP segments', () {
        final Uint8List jpeg = _buildJpeg(640, 480);
        final ImageHeader? header = ImageHeaderParser.parse(jpeg);
        expect(header!.width, 640);
        expect(header.height, 480);
      });

      test('reads progressive SOF2 dimensions', () {
        final Uint8List jpeg = _buildJpeg(800, 600, sofMarker: 0xC2);
        final ImageHeader? header = ImageHeaderParser.parse(jpeg);
        expect(header!.width, 800);
        expect(header.height, 600);
      });

      test('skips EXIF-style payloads spanning multiple APP segments', () {
        // Segment length is a 16-bit field, so a >64KB prefix needs two APP1s.
        final Uint8List jpeg = _buildJpeg(
          1000,
          2000,
          appSegments: <int>[60000, 60000],
        );
        final ImageHeader? header = ImageHeaderParser.parse(jpeg);
        expect(header!.width, 1000);
        expect(header.height, 2000);
      });

      test('rejects JPEG with no SOF before end of data', () {
        // SOI + one APP1 segment, then truncated.
        final Uint8List jpeg = _buildJpeg(10, 10, includeSof: false);
        expect(ImageHeaderParser.parse(jpeg), isNull);
      });

      test('rejects garbage after SOI', () {
        final Uint8List bytes = Uint8List.fromList(<int>[
          0xFF, 0xD8, 0x00, 0x01, 0x02, 0x03,
        ]);
        expect(ImageHeaderParser.parse(bytes), isNull);
      });
    });

    group('WebP', () {
      test('reads VP8X (extended) canvas dimensions', () {
        final Uint8List webp = _buildWebPVp8x(2048, 1152);
        final ImageHeader? header = ImageHeaderParser.parse(webp);
        expect(header!.width, 2048);
        expect(header.height, 1152);
      });

      test('reads VP8 (lossy) dimensions', () {
        final Uint8List webp = _buildWebPLossy(550, 368);
        final ImageHeader? header = ImageHeaderParser.parse(webp);
        expect(header!.width, 550);
        expect(header.height, 368);
      });

      test('reads VP8L (lossless) dimensions', () {
        final Uint8List webp = _buildWebPLossless(331, 557);
        final ImageHeader? header = ImageHeaderParser.parse(webp);
        expect(header!.width, 331);
        expect(header.height, 557);
      });

      test('rejects unknown WebP chunk', () {
        final Uint8List webp = _buildWebPVp8x(10, 10)
          ..setRange(12, 16, 'ANIM'.codeUnits);
        expect(ImageHeaderParser.parse(webp), isNull);
      });
    });

    test('returns null for unknown or short data', () {
      expect(ImageHeaderParser.parse(Uint8List(0)), isNull);
      expect(
        ImageHeaderParser.parse(Uint8List.fromList(<int>[1, 2, 3])),
        isNull,
      );
      expect(
        ImageHeaderParser.parse(Uint8List.fromList(List<int>.filled(64, 0x7F))),
        isNull,
      );
    });
  });

  group('ImageHeaderParser.parseFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('header_parser_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    File write(String name, List<int> bytes) {
      final File file = File('${tempDir.path}/$name');
      file.writeAsBytesSync(bytes);
      return file;
    }

    test('matches real encoded PNG dimensions', () async {
      final img.Image image = img.Image(width: 320, height: 200);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final File file = write('real.png', img.encodePng(image));
      final ImageHeader? header = await ImageHeaderParser.parseFile(file);
      expect(header!.width, 320);
      expect(header.height, 200);
    });

    test('matches real encoded JPEG dimensions', () async {
      final img.Image image = img.Image(width: 640, height: 400);
      img.fill(image, color: img.ColorRgb8(0, 255, 0));
      final File file = write('real.jpg', img.encodeJpg(image));
      final ImageHeader? header = await ImageHeaderParser.parseFile(file);
      expect(header!.width, 640);
      expect(header.height, 400);
    });

    test('parses when SOF sits beyond the first read chunk', () async {
      // 40KB of APP1 padding pushes SOF past the 32KB initial read.
      final Uint8List jpeg = _buildJpeg(123, 456, appSegments: <int>[40000]);
      final File file = write('exif.jpg', jpeg);
      final ImageHeader? header = await ImageHeaderParser.parseFile(file);
      expect(header!.width, 123);
      expect(header.height, 456);
    });

    test('returns null for empty or garbage files', () async {
      final File empty = write('empty.jpg', <int>[]);
      expect(await ImageHeaderParser.parseFile(empty), isNull);

      final File garbage = write('garbage.png', List<int>.filled(100, 1));
      expect(await ImageHeaderParser.parseFile(garbage), isNull);
    });

    test('returns null for missing file', () async {
      final File missing = File('${tempDir.path}/missing.jpg');
      expect(await ImageHeaderParser.parseFile(missing), isNull);
    });
  });
}

/// Minimal PNG header: signature + IHDR chunk with the given dimensions.
Uint8List _buildPng(int width, int height) {
  final ByteData ihdr = ByteData(13);
  ihdr.setUint32(0, width);
  ihdr.setUint32(4, height);
  ihdr.setUint8(8, 8); // bit depth
  ihdr.setUint8(9, 2); // color type
  return Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0, 0, 0, 13, // IHDR length
    0x49, 0x48, 0x44, 0x52, // 'IHDR'
    ...ihdr.buffer.asUint8List(),
    0, 0, 0, 0, // CRC (not parsed)
  ]);
}

/// Minimal JPEG structure: SOI, optional APP1 segments of the given sizes,
/// then an SOF marker carrying the dimensions.
Uint8List _buildJpeg(
  int width,
  int height, {
  int sofMarker = 0xC0,
  List<int> appSegments = const <int>[16],
  bool includeSof = true,
}) {
  final List<int> bytes = <int>[0xFF, 0xD8];
  for (final int size in appSegments) {
    bytes
      ..add(0xFF)
      ..add(0xE1)
      ..add((size >> 8) & 0xFF)
      ..add(size & 0xFF)
      ..addAll(List<int>.filled(size - 2, 0x00));
  }
  if (includeSof) {
    const int precision = 8;
    bytes
      ..add(0xFF)
      ..add(sofMarker)
      ..add(0x00)
      ..add(11) // segment length
      ..add(precision)
      ..add((height >> 8) & 0xFF)
      ..add(height & 0xFF)
      ..add((width >> 8) & 0xFF)
      ..add(width & 0xFF)
      ..addAll(<int>[1, 0x22, 0x00, 0x11, 0x00]); // component specs
  }
  bytes.addAll(<int>[0xFF, 0xD9]); // EOI
  return Uint8List.fromList(bytes);
}

Uint8List _riff(String fourcc, List<int> payload) {
  final int size = payload.length;
  return Uint8List.fromList(<int>[
    0x52, 0x49, 0x46, 0x46, // 'RIFF'
    size & 0xFF, (size >> 8) & 0xFF, (size >> 16) & 0xFF, (size >> 24) & 0xFF,
    0x57, 0x45, 0x42, 0x50, // 'WEBP'
    ...fourcc.codeUnits,
    size & 0xFF, (size >> 8) & 0xFF, (size >> 16) & 0xFF, (size >> 24) & 0xFF,
    ...payload,
  ]);
}

/// VP8X payload: 4 flag bytes then canvas width-1/height-1 as LE24 each.
Uint8List _buildWebPVp8x(int width, int height) {
  int le24(int value) =>
      value & 0xFF | ((value >> 8) & 0xFF) << 8 | ((value >> 16) & 0xFF) << 16;
  return _riff(
    'VP8X',
    <int>[
      0x00, 0x00, 0x00, 0x00, // flags
      le24(width - 1) & 0xFF,
      (le24(width - 1) >> 8) & 0xFF,
      (le24(width - 1) >> 16) & 0xFF,
      le24(height - 1) & 0xFF,
      (le24(height - 1) >> 8) & 0xFF,
      (le24(height - 1) >> 16) & 0xFF,
      ...List<int>.filled(4, 0),
    ],
  );
}

/// VP8 keyframe payload: 3-byte frame tag, sync code, LE16 dims.
Uint8List _buildWebPLossy(int width, int height) {
  return _riff('VP8 ', <int>[
    0x30, 0x01, 0x00, // frame tag (keyframe)
    0x9D, 0x01, 0x2A, // sync code
    width & 0xFF, (width >> 8) & 0xFF,
    height & 0xFF, (height >> 8) & 0xFF,
    ...List<int>.filled(10, 0),
  ]);
}

/// VP8L payload: 0x2F signature then 14-bit width-1/height-1 packed LE.
Uint8List _buildWebPLossless(int width, int height) {
  final int bits = (width - 1) | ((height - 1) << 14);
  return _riff('VP8L', <int>[
    0x2F,
    bits & 0xFF,
    (bits >> 8) & 0xFF,
    (bits >> 16) & 0xFF,
    (bits >> 24) & 0xFF,
    ...List<int>.filled(4, 0),
  ]);
}

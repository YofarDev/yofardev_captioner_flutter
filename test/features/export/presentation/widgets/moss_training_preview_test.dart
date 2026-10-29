import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yofardev_captioner/features/export/presentation/widgets/moss_training_preview.dart';

/// Writes a real PNG whose pixel (1,1) is a known landmark color so pixel
/// and box alignment can be reasoned about together.
Uint8List pngBytes(int width, int height) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(10, 10, 10));
  img.drawPixel(image, 1, 1, img.ColorRgb8(255, 0, 0));
  return Uint8List.fromList(img.encodePng(image));
}

/// Records drawRect calls and returns the first drawn rect.
class _RecordingCanvas implements Canvas {
  final List<Rect> rects = <Rect>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  void drawRect(Rect rect, Paint paint) {
    rects.add(rect);
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {}
}

/// Paints [painter] against the recording canvas and returns the first
/// drawn rect.
Rect paintedRect(CustomPainter painter, Size size) {
  final _RecordingCanvas canvas = _RecordingCanvas();
  painter.paint(canvas, size);
  assert(canvas.rects.isNotEmpty, 'painter drew nothing');
  return canvas.rects.first;
}

void main() {
  late Directory tempDir;
  late File png;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('preview_test');
    png = File('${tempDir.path}/a.png')..writeAsBytesSync(pngBytes(400, 200));
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  // Codex rev-3 finding 2: ONE contain scale must drive image positioning
  // AND box painting, for portrait AND landscape windows — pixels and boxes
  // can never use different scales.
  group('MossCropPreviewPane geometry', () {
    Future<void> pumpPane(
      WidgetTester tester, {
      required int viewWidth,
      required int viewHeight,
      required int paneWidth,
      required int paneHeight,
    }) async {
      tester.view.physicalSize = Size(paneWidth * 4.0, paneHeight * 4.0 + 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: paneWidth.toDouble(),
                height: paneHeight.toDouble(),
                child: MossCropPreviewPane(
                  imagePath: png.path,
                  imageWidth: 400,
                  imageHeight: 200,
                  viewLeft: 0,
                  viewTop: 0,
                  viewWidth: viewWidth,
                  viewHeight: viewHeight,
                  boxes: <List<int>>[
                    <int>[
                      viewWidth ~/ 4,
                      viewHeight ~/ 4,
                      viewWidth * 3 ~/ 4,
                      viewHeight * 3 ~/ 4,
                    ],
                  ],
                  label: 'test',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('portrait view: image and boxes share the contain scale', (
      WidgetTester tester,
    ) async {
      // View window 200×600 (portrait) inside a 150×150 pane:
      // scale = min(150/200, 150/600) = 0.25 → viewport 50×150.
      await pumpPane(
        tester,
        viewWidth: 200,
        viewHeight: 600,
        paneWidth: 150,
        paneHeight: 150,
      );
      // Documented ideal: pane-square → 0.25 (asserted in the pure-scale
      // test below). The layout assertions verify the widget against its
      // MEASURED scale, since the label shrinks the LayoutBuilder height.
      final Size imageSize = tester.getSize(find.byType(Image));
      // MEASURED scale of the rendered image pixels.
      final double measuredScale = imageSize.width / 400;
      // The viewport (SizedBox wrapping the stack) uses the SAME scale.
      final Rect viewport = tester.getRect(
        find
            .ancestor(
              of: find.byType(ClipRect),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(
        viewport.width,
        closeTo(200 * measuredScale, 0.5),
        reason: 'viewport width must use the image scale',
      );
      expect(
        viewport.height,
        closeTo(600 * measuredScale, 0.5),
        reason: 'viewport height must use the image scale',
      );
      // The contain property: the viewport fits inside the pane along the
      // constrained axis (portrait → height-bound).
      expect(viewport.height, lessThanOrEqualTo(150.5));
      // The box painter uses the SAME scale the image is drawn with: the
      // on-screen quarter box equals source box × measuredScale.
      final Rect drawn = paintedRect(
        TrainingBoxPainter(
          viewWidth: 200,
          viewHeight: 600,
          boxes: <List<int>?>[
            <int>[50, 150, 150, 450],
          ],
          scale: measuredScale,
        ),
        viewport.size,
      );
      expect(drawn.left, closeTo(50 * measuredScale, 0.01));
      expect(drawn.top, closeTo(150 * measuredScale, 0.01));
      expect(drawn.right, closeTo(150 * measuredScale, 0.01));
      expect(drawn.bottom, closeTo(450 * measuredScale, 0.01));
      // Painter rect lies inside the image extent drawn at the same scale:
      // image spans (-0,0)-(100,50) in viewport coordinates — the box in
      // viewport coords (12.5,37.5)-(37.5,112.5) exceeds it vertically
      // because the view window (portrait) is TALLER than the source
      // image: exactly the case the old code misaligned.
      // drawn is in the pane's local coordinates: must fit the viewport.
      expect(
        drawn.topLeft >= Offset.zero && drawn.bottomRight <= viewport.size,
        isTrue,
        reason: 'box at $drawn must fit viewport ${viewport.size}',
      );
    });

    testWidgets('landscape view: same single scale for pixels and boxes', (
      WidgetTester tester,
    ) async {
      // View window 600×200 (landscape) inside a 150×150 pane:
      // scale = min(150/600, 150/200) = 0.25 → viewport 150×50.
      await pumpPane(
        tester,
        viewWidth: 600,
        viewHeight: 200,
        paneWidth: 150,
        paneHeight: 150,
      );
      final Size imageSize = tester.getSize(find.byType(Image));
      final double measuredScale = imageSize.width / 400;
      final Rect viewport = tester.getRect(
        find
            .ancestor(
              of: find.byType(ClipRect),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(
        viewport.width,
        closeTo(600 * measuredScale, 0.5),
        reason: 'viewport width must use the image scale',
      );
      expect(
        viewport.height,
        closeTo(200 * measuredScale, 0.5),
        reason: 'viewport height must use the image scale',
      );
      // Landscape in a square-ish pane → width-bound.
      expect(viewport.width, lessThanOrEqualTo(150.5));
      // Quarter box drawn at the same measured scale as the pixels.
      final Rect drawn = paintedRect(
        TrainingBoxPainter(
          viewWidth: 600,
          viewHeight: 200,
          boxes: <List<int>?>[
            <int>[150, 50, 450, 150],
          ],
          scale: measuredScale,
        ),
        viewport.size,
      );
      expect(drawn.left, closeTo(150 * measuredScale, 0.01));
      expect(drawn.top, closeTo(50 * measuredScale, 0.01));
      expect(drawn.right, closeTo(450 * measuredScale, 0.01));
      expect(drawn.bottom, closeTo(150 * measuredScale, 0.01));
      // drawn is in the pane's local coordinates: must fit the viewport.
      expect(
        drawn.topLeft >= Offset.zero && drawn.bottomRight <= viewport.size,
        isTrue,
        reason: 'box at $drawn must fit viewport ${viewport.size}',
      );
    });

    test('contain scale picks the constrained axis for portrait/landscape', () {
      expect(
        MossCropPreviewPane.containScale(
          maxWidth: 100,
          maxHeight: 50,
          viewWidth: 200,
          viewHeight: 600,
        ),
        closeTo(50 / 600, 1e-9),
      ); // tall view in short pane → height-constrained
      expect(
        MossCropPreviewPane.containScale(
          maxWidth: 100,
          maxHeight: 50,
          viewWidth: 600,
          viewHeight: 200,
        ),
        closeTo(100 / 600, 1e-9),
      ); // wide view in narrow pane → width-constrained
    });

    test('shouldRepaint covers geometry inputs', () {
      const TrainingBoxPainter painter = TrainingBoxPainter(
        viewWidth: 100,
        viewHeight: 100,
        boxes: <List<int>?>[
          <int>[0, 0, 10, 10],
        ],
        scale: 1.0,
      );
      expect(
        painter.shouldRepaint(
          const TrainingBoxPainter(
            viewWidth: 100,
            viewHeight: 100,
            boxes: <List<int>?>[
              <int>[0, 0, 10, 10],
            ],
            scale: 2.0,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const TrainingBoxPainter(
            viewWidth: 200,
            viewHeight: 100,
            boxes: <List<int>?>[
              <int>[0, 0, 10, 10],
            ],
            scale: 1.0,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const TrainingBoxPainter(
            viewWidth: 100,
            viewHeight: 100,
            boxes: <List<int>?>[
              <int>[0, 0, 20, 10],
            ],
            scale: 1.0,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          const TrainingBoxPainter(
            viewWidth: 100,
            viewHeight: 100,
            boxes: <List<int>?>[
              <int>[0, 0, 10, 10],
            ],
            scale: 1.0,
          ),
        ),
        isFalse,
      );
    });
  });
}

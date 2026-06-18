import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/image_eyedropper_dialog.dart';

/// Writes a solid-color PNG of [w]x[h] to a temp file and returns it.
File _solidPng(int w, int h, img.ColorRgb8 color) {
  final img.Image image = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      image.setPixel(x, y, color);
    }
  }
  final Directory tmp = Directory.systemTemp.createTempSync('eyedropper_test_');
  final File file = File('${tmp.path}/solid.png');
  file.writeAsBytesSync(img.encodePng(image));
  return file;
}

void main() {
  testWidgets('tap on the image returns the center pixel hex',
      (WidgetTester tester) async {
    final File file = _solidPng(200, 200, img.ColorRgb8(255, 0, 0));

    late BuildContext capturedCtx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext c) {
            capturedCtx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    // _decode() reads the file via real dart:io (File.readAsBytes). Its native
    // completion only fires on the real event loop, and showDialog's result
    // completer lives in whatever zone it was created in — so we mount the
    // dialog, drive the pick, and await the result ALL inside the same
    // [WidgetTester.runAsync] block. Timed pumps are used (never pumpAndSettle)
    // while the loading CircularProgressIndicator could be visible, since an
    // indefinite animation never settles.
    String? picked;
    await tester.runAsync(() async {
      final Future<String?> result =
          showImageEyedropperDialog(capturedCtx, imageFile: file);
      await tester.pump(); // mount dialog → initState kicks off _decode()
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      ); // let real I/O + decode finish
      await tester.pump(); // rebuild after the post-decode setState
      await tester.pump(const Duration(milliseconds: 10));

      // Tap the center of the pickable body (the image is centered, so the body
      // center == painted-image center == pixel (100, 100) == #FF0000).
      final Offset center = tester.getCenter(
        find.byKey(const ValueKey<String>('eyedropper-body')),
      );
      await tester.tapAt(center);
      await tester.pumpAndSettle(); // dialog dismissed

      picked = await result;
    });

    expect(picked, '#FF0000');
  });

  testWidgets('tap in the letterbox is ignored (no pick)',
      (WidgetTester tester) async {
    final File file = _solidPng(200, 200, img.ColorRgb8(0, 255, 0));

    late BuildContext capturedCtx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext c) {
            capturedCtx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    await tester.runAsync(() async {
      showImageEyedropperDialog(capturedCtx, imageFile: file);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      // Tap far in the left letterbox (outside the painted image rect).
      await tester.tapAt(const Offset(5, 100));
      await tester.pump();
    });

    // Dialog still open → body still present (the tap was ignored).
    expect(
      find.byKey(const ValueKey<String>('eyedropper-body')),
      findsOneWidget,
    );

    // Close the dialog cleanly so the test ends.
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error message when the image cannot be decoded',
      (WidgetTester tester) async {
    final Directory tmp = Directory.systemTemp.createTempSync('eyedropper_bad_');
    final File bad = File('${tmp.path}/not-an-image.png');
    bad.writeAsBytesSync(<int>[0, 1, 2, 3]); // garbage bytes

    late BuildContext capturedCtx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext c) {
            capturedCtx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );

    String? closed;
    await tester.runAsync(() async {
      final Future<String?> result =
          showImageEyedropperDialog(capturedCtx, imageFile: bad);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('Could not load image'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      closed = await result;
    });

    expect(closed, isNull);
  });
}

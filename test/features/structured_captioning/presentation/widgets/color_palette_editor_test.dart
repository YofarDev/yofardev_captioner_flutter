import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/color_palette_editor.dart';

void main() {
  // ponytail: harness wraps the editor and forwards onChanged to a captor.
  List<String>? captured;
  Widget harness({
    required List<String> colors,
    required ValueChanged<List<String>> onChanged,
  }) => MaterialApp(
    home: Scaffold(
      body: ColorPaletteEditor(
        colors: colors,
        onChanged: onChanged,
        imageFile: File('/x/y.jpg'),
      ),
    ),
  );

  testWidgets('renders one swatch per color plus the add button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        colors: <String>['#FF0000', '#00FF00', '#0000FF'],
        onChanged: (_) {},
      ),
    );

    // Three swatches (Tooltips with the hex message) + one add button.
    expect(find.byTooltip('#FF0000\n(right-click to remove)'), findsOneWidget);
    expect(find.byTooltip('#00FF00\n(right-click to remove)'), findsOneWidget);
    expect(find.byTooltip('#0000FF\n(right-click to remove)'), findsOneWidget);
    expect(find.byTooltip('Add color'), findsOneWidget);
  });

  testWidgets('renders only the add button when colors list is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(colors: <String>[], onChanged: (_) {}));

    expect(find.byType(GestureDetector), findsOneWidget); // add button only
    expect(find.byTooltip('Add color'), findsOneWidget);
  });

  testWidgets(
    'right-click on a swatch calls onChanged with the color removed',
    (WidgetTester tester) async {
      captured = null;
      await tester.pumpWidget(
        harness(
          colors: <String>['#FF0000', '#00FF00', '#0000FF'],
          onChanged: (List<String> updated) => captured = updated,
        ),
      );

      // Secondary tap (right-click) on the middle swatch.
      await tester.tap(
        find.byTooltip('#00FF00\n(right-click to remove)'),
        buttons: kSecondaryButton,
      );
      await tester.pump();

      expect(captured, <String>['#FF0000', '#0000FF']);
    },
  );

  testWidgets('right-click on the only swatch yields an empty list', (
    WidgetTester tester,
  ) async {
    captured = null;
    await tester.pumpWidget(
      harness(
        colors: <String>['#FF0000'],
        onChanged: (List<String> updated) => captured = updated,
      ),
    );

    await tester.tap(
      find.byTooltip('#FF0000\n(right-click to remove)'),
      buttons: kSecondaryButton,
    );
    await tester.pump();

    expect(captured, <String>[]);
  });
}

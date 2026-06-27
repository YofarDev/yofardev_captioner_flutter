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
    expect(
      find.byTooltip('#FF0000\n(long-press copy, right-click remove)'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('#00FF00\n(long-press copy, right-click remove)'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('#0000FF\n(long-press copy, right-click remove)'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Add color (eyedropper)\nlong-press to paste from clipboard'),
      findsOneWidget,
    );
  });

  testWidgets('renders only the add button when colors list is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(colors: <String>[], onChanged: (_) {}));

    expect(find.byType(GestureDetector), findsOneWidget); // add button only
    expect(
      find.byTooltip('Add color (eyedropper)\nlong-press to paste from clipboard'),
      findsOneWidget,
    );
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
        find.byTooltip('#00FF00\n(long-press copy, right-click remove)'),
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
      find.byTooltip('#FF0000\n(long-press copy, right-click remove)'),
      buttons: kSecondaryButton,
    );
    await tester.pump();

    expect(captured, <String>[]);
  });

  // ponytail: the long-press paste path itself can't be driven through the
  // Tooltip (it steals the gesture), so cover the clipboard-paste parser it
  // depends on directly. See ColorPaletteEditor.parseColorHex.
  group('ColorPaletteEditor.parseColorHex', () {
    test('returns null for null/empty/non-hex input', () {
      expect(ColorPaletteEditor.parseColorHex(null), isNull);
      expect(ColorPaletteEditor.parseColorHex(''), isNull);
      expect(ColorPaletteEditor.parseColorHex('nope'), isNull);
      expect(ColorPaletteEditor.parseColorHex('#GGGGGG'), isNull);
      expect(ColorPaletteEditor.parseColorHex('12345'), isNull);
    });

    test('normalizes a 6-digit hex to uppercase with a leading #', () {
      expect(ColorPaletteEditor.parseColorHex('aabbcc'), '#AABBCC');
      expect(ColorPaletteEditor.parseColorHex('#a1b2c3'), '#A1B2C3');
      expect(ColorPaletteEditor.parseColorHex('  #ff00ff  '), '#FF00FF');
    });

    test('strips an 8-digit alpha prefix down to RGB', () {
      expect(ColorPaletteEditor.parseColorHex('FF112233'), '#112233');
      expect(ColorPaletteEditor.parseColorHex('#80DEADBE'), '#DEADBE');
    });
  });
}

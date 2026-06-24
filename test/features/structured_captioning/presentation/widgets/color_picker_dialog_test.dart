import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/color_picker_dialog.dart';

void main() {
  // ponytail: open the dialog via a launcher button; return a Completer that
  // resolves with whatever showColorPickerDialog returned.
  Future<Completer<String?>> pumpAndOpen(
    WidgetTester tester, {
    String? initialColor,
  }) async {
    final Completer<String?> completer = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final String? result = await showColorPickerDialog(
                    context,
                    initialColor: initialColor,
                  );
                  completer.complete(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return completer;
  }

  testWidgets('Cancel returns null', (WidgetTester tester) async {
    final Completer<String?> completer = await pumpAndOpen(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await completer.future, isNull);
  });

  testWidgets('Select returns the current color hex when no edits made', (
    WidgetTester tester,
  ) async {
    // Open with an explicit initial color so we know exactly what to expect.
    const String initialHex = '#FF0000';
    final Completer<String?> completer = await pumpAndOpen(
      tester,
      initialColor: initialHex,
    );

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    final String? result = await completer.future;
    expect(result, isNotNull);
    // ponytail: exact formatting may differ by SDK (#FF vs #FF0000), so assert
    // on the normalized uppercase hex without depending on padding length.
    expect(result!.toUpperCase(), contains('FF0000'));
  });

  testWidgets('shows both action buttons and current color readout', (
    WidgetTester tester,
  ) async {
    await pumpAndOpen(tester, initialColor: '#3366CC');

    expect(find.text('Pick a color'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    // The readout text shows the current color hex.
    expect(find.textContaining('#'), findsWidgets);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/recaption_element_dialog.dart';

void main() {
  // Pumps the launcher harness, opens the dialog, and returns a Completer that
  // resolves with whatever `showRecaptionElementDialog` returns. Each tester
  // API is fully awaited so flutter_test's async guard never sees overlapping
  // guarded calls.
  Future<Completer<String?>> pumpHarness(WidgetTester tester) async {
    final Completer<String?> completer = Completer<String?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  completer.complete(await showRecaptionElementDialog(context));
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

  testWidgets('returns null on cancel', (WidgetTester tester) async {
    final Completer<String?> completer = await pumpHarness(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await completer.future, isNull);
  });

  testWidgets('returns empty string when recaptioning with no instructions',
      (WidgetTester tester) async {
    final Completer<String?> completer = await pumpHarness(tester);
    await tester.tap(find.text('Recaption'));
    await tester.pumpAndSettle();
    expect(await completer.future, '');
  });

  testWidgets('returns typed instructions', (WidgetTester tester) async {
    final Completer<String?> completer = await pumpHarness(tester);
    await tester.enterText(find.byType(TextField), 'focus on the branding');
    await tester.tap(find.text('Recaption'));
    await tester.pumpAndSettle();
    expect(await completer.future, 'focus on the branding');
  });
}

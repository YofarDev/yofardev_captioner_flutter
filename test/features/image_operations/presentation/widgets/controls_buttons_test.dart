import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/image_operations/presentation/widgets/controls_widgets.dart';

void main() {
  testWidgets('SettingsButton delegates to onPressed', (
    WidgetTester tester,
  ) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsButton(onPressed: () => pressed = true)),
      ),
    );

    await tester.tap(find.byIcon(Icons.tune));
    expect(pressed, isTrue);
  });

  testWidgets('PickFolderButton renders and exposes the callback', (
    WidgetTester tester,
  ) async {
    // FilePicker's platform channel is not stubbed in tests, so the tap path
    // is not exercised here — this pins the constructor contract and label.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PickFolderButton(onFolderPicked: (String folderPath) {}),
        ),
      ),
    );

    expect(find.text('Pick folder'), findsOneWidget);
  });
}

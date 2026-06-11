import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/widgets/notification_overlay.dart';

void main() {
  group('NotificationOverlay', () {
    testWidgets('show inserts overlay with message text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _OverlayTestHelper(message: 'Test notification'),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Test notification'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Flush the auto-hide timer so test doesn't fail with pending timers
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
    });

    testWidgets('show uses custom colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _OverlayTestHelper(
              message: 'Custom color',
              backgroundColor: Colors.red,
              textColor: Colors.yellow,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Custom color'), findsOneWidget);

      final Text textWidget = tester.widget<Text>(find.text('Custom color'));
      expect(textWidget.style?.color, Colors.yellow);

      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
    });

    testWidgets('auto-hide removes overlay after duration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _OverlayTestHelper(
              message: 'Auto hide',
              duration: Duration(seconds: 1),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Notification is visible
      expect(find.text('Auto hide'), findsOneWidget);

      // Advance past the duration
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Notification should be removed
      expect(find.text('Auto hide'), findsNothing);
    });
  });
}

/// Helper widget that provides an Overlay and a button to trigger
/// [NotificationOverlay.show].
class _OverlayTestHelper extends StatelessWidget {
  const _OverlayTestHelper({
    required this.message,
    this.backgroundColor = Colors.black87,
    this.textColor = Colors.white,
    this.duration = const Duration(seconds: 30),
  });

  final String message;
  final Color backgroundColor;
  final Color textColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: <OverlayEntry>[
        OverlayEntry(
          builder: (BuildContext context) {
            return Column(
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    NotificationOverlay.show(
                      context,
                      message: message,
                      backgroundColor: backgroundColor,
                      textColor: textColor,
                      duration: duration,
                    );
                  },
                  child: const Text('Show'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

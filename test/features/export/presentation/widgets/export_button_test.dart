import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/export/presentation/widgets/export_button.dart';

void main() {
  group('ExportButton Widget', () {
    testWidgets('should render export button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportButton(),
          ),
        ),
      );

      expect(find.text('💾  Export as Archive'), findsOneWidget);
    });

    testWidgets('should have correct button styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportButton(),
          ),
        ),
      );

      final Finder button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);

      final ElevatedButton elevatedButton =
          tester.widget<ElevatedButton>(button);
      expect(elevatedButton.style, isNotNull);
    });
  });
}

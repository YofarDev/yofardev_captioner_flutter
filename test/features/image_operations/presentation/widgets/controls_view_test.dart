import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/image_operations/presentation/widgets/controls_view.dart';

void main() {
  testWidgets('renders all four slots and the project-actions header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ControlsView(
            searchAndReplace: Text('slot-search'),
            captionFiles: Text('slot-caption-files'),
            export: Text('slot-export'),
            captionControls: Text('slot-run-controls'),
          ),
        ),
      ),
    );

    expect(find.text('slot-search'), findsOneWidget);
    expect(find.text('slot-caption-files'), findsOneWidget);
    expect(find.text('slot-export'), findsOneWidget);
    expect(find.text('slot-run-controls'), findsOneWidget);
    expect(find.text('Generate Captions'), findsOneWidget);
  });
}

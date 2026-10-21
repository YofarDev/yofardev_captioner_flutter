import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/image_operations/presentation/widgets/controls_view.dart';

void main() {
  testWidgets('renders all four slots and the project-actions header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ControlsView(
            onFolderPicked: (_) {},
            searchAndReplace: const Text('slot-search'),
            captionFiles: const Text('slot-caption-files'),
            export: const Text('slot-export'),
            captionControls: const Text('slot-run-controls'),
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

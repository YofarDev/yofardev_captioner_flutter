import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/features/agent_api/presentation/widgets/agent_api_panel.dart';

/// Widget test for the Agent API settings panel. The panel resolves
/// [AgentApiService] from the locator, so the full (side-effect free) DI
/// graph is registered first — this doubles as a smoke check that the
/// agent_api presentation slice is DI-only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  setUpAll(() {
    registerDependencies(locator);
  });

  tearDownAll(() async {
    await locator.reset();
  });

  testWidgets('shows status, description, and port controls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 900, child: AgentApiPanel()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('AGENT API'), findsOneWidget);
    // The embedded server is not started in the test: status is Stopped.
    expect(find.text('Stopped'), findsOneWidget);
    expect(find.textContaining('bearer token'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}

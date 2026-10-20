import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/features/llm_config/data/repositories/llm_config_service.dart';
import 'package:yofardev_captioner/features/llm_config/presentation/bloc/llm_configs_cubit.dart';
import 'package:yofardev_captioner/features/llm_config/presentation/pages/llm_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // AgentApiPanel resolves its service from the locator; register the full
  // graph (side-effect free) so every settings tab can build.
  setUpAll(() {
    registerDependencies(locator);
  });

  tearDownAll(() async {
    await locator.reset();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final LlmConfigsCubit cubit = LlmConfigsCubit(
      llmConfigService: LlmConfigService(),
    );
    addTearDown(cubit.close);

    // Desktop-sized surface — the settings shell is authored for it.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<LlmConfigsCubit>.value(
        value: cubit,
        child: const MaterialApp(home: LlmSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('LlmSettingsScreen', () {
    testWidgets('opens on the Models & Prompts tab', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('VISION MODEL SETTINGS'), findsOneWidget);
      expect(find.text('Models & Prompts'), findsOneWidget);
      expect(find.text('Agent API'), findsOneWidget);
      expect(find.text('Structured'), findsOneWidget);
    });

    testWidgets('switches to the Structured tab and shows pipeline toggles', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Structured'));
      await tester.pump();

      expect(find.text('STRUCTURED CAPTIONS'), findsOneWidget);
    });

    testWidgets('switches to the Agent API tab and shows server controls', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Agent API'));
      await tester.pump();

      expect(find.textContaining('Port'), findsWidgets);
    });
  });
}

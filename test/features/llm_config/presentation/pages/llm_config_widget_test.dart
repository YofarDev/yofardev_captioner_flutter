import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_configs.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/llm_config/logic/llm_configs_cubit.dart';
import 'package:yofardev_captioner/features/llm_config/presentation/pages/llm_config_widget.dart';

/// [LlmConfigsCubit] exposes a test-only emitter so we can drive arbitrary
/// states into the widget without triggering persistence or DI.
class _FakeLlmConfigsCubit extends LlmConfigsCubit {
  _FakeLlmConfigsCubit() : super();

  void emitState(LlmConfigsState next) => emit(next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  Widget buildSubject(_FakeLlmConfigsCubit cubit) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<LlmConfigsCubit>.value(
          value: cubit,
          child: const LlmConfigWidget(),
        ),
      ),
    );
  }

  LlmConfigsState twoConfigs(String selectedId) => LlmConfigsState(
    llmConfigs: LlmConfigs(
      configs: <LlmConfig>[
        LlmConfig(
          id: 'a',
          name: 'Remote Model',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        ),
        LlmConfig(
          id: 'b',
          name: 'Local MLX',
          model: 'mlx',
          providerType: LlmProviderType.localMlx,
        ),
      ],
      prompts: const <String>[],
      selectedConfigId: selectedId,
    ),
  );

  group('LlmConfigWidget', () {
    testWidgets('shows hint when no configs available', (
      WidgetTester tester,
    ) async {
      final _FakeLlmConfigsCubit cubit = _FakeLlmConfigsCubit();
      addTearDown(cubit.close);

      await tester.pumpWidget(buildSubject(cubit));

      expect(find.text('Select Model'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('renders the selected config name', (
      WidgetTester tester,
    ) async {
      final _FakeLlmConfigsCubit cubit = _FakeLlmConfigsCubit();
      addTearDown(cubit.close);
      cubit.emitState(twoConfigs('b'));

      await tester.pumpWidget(buildSubject(cubit));

      expect(find.text('Local MLX'), findsOneWidget);
      expect(find.text('Select Model'), findsNothing);
    });
  });
}

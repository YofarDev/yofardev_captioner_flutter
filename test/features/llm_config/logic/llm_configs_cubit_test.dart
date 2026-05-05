import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_configs.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/llm_config/logic/llm_configs_cubit.dart';

@GenerateMocks(<Type>[])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LlmConfigsCubit', () {
    late LlmConfigsCubit cubit;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      cubit = LlmConfigsCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has empty configs and default prompts', () {
      expect(cubit.state.llmConfigs.configs, isEmpty);
      expect(cubit.state.llmConfigs.selectedConfigId, isNull);
      expect(cubit.state.llmConfigs.prompts.length, 2);
      expect(cubit.state.llmConfigs.selectedPrompt, isNotNull);
    });

    group('addLlmConfig', () {
      test('adds config and selects it when none selected', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        cubit.addLlmConfig(config);

        expect(cubit.state.llmConfigs.configs.length, 1);
        expect(cubit.state.llmConfigs.selectedConfigId, 'cfg1');
      });

      test(
        'adds config without changing selection when one is already selected',
        () {
          final LlmConfig config1 = LlmConfig(
            id: 'cfg1',
            name: 'First',
            model: 'gpt-4',
            providerType: LlmProviderType.remote,
          );
          final LlmConfig config2 = LlmConfig(
            id: 'cfg2',
            name: 'Second',
            model: 'gpt-4',
            providerType: LlmProviderType.remote,
          );

          cubit.addLlmConfig(config1);
          cubit.addLlmConfig(config2);

          expect(cubit.state.llmConfigs.configs.length, 2);
          expect(cubit.state.llmConfigs.selectedConfigId, 'cfg1');
        },
      );
    });

    group('updateLlmConfig', () {
      test('updates existing config by id', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'Original',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        cubit.addLlmConfig(config);

        final LlmConfig updated = config.copyWith(name: 'Updated');
        cubit.updateLlmConfig(updated);

        expect(cubit.state.llmConfigs.configs.first.name, 'Updated');
        expect(cubit.state.llmConfigs.configs.first.id, 'cfg1');
      });
    });

    group('deleteLlmConfig', () {
      test('removes config', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        cubit.addLlmConfig(config);

        cubit.deleteLlmConfig('cfg1');

        expect(cubit.state.llmConfigs.configs, isEmpty);
      });

      test('clears selectedConfigId when deleting selected config', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        cubit.addLlmConfig(config);

        cubit.deleteLlmConfig('cfg1');

        expect(cubit.state.llmConfigs.selectedConfigId, isNull);
      });

      test('keeps selectedConfigId when deleting non-selected config', () {
        final LlmConfig config1 = LlmConfig(
          id: 'cfg1',
          name: 'First',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        final LlmConfig config2 = LlmConfig(
          id: 'cfg2',
          name: 'Second',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        cubit.addLlmConfig(config1);
        cubit.addLlmConfig(config2);

        cubit.deleteLlmConfig('cfg2');

        expect(cubit.state.llmConfigs.selectedConfigId, 'cfg1');
        expect(cubit.state.llmConfigs.configs.length, 1);
      });
    });

    group('duplicateLlmConfig', () {
      test('creates copy with "(copy)" suffix and selects it', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'MyModel',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
          apiKey: 'key123',
        );
        cubit.addLlmConfig(config);

        cubit.duplicateLlmConfig('cfg1');

        expect(cubit.state.llmConfigs.configs.length, 2);
        final LlmConfig dup = cubit.state.llmConfigs.configs.last;
        expect(dup.name, 'MyModel (copy)');
        expect(dup.model, 'gpt-4');
        expect(dup.apiKey, 'key123');
        expect(dup.id, isNot(equals('cfg1')));
        expect(cubit.state.llmConfigs.selectedConfigId, dup.id);
      });
    });

    group('selectLlmConfig', () {
      test('updates selectedConfigId', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        cubit.addLlmConfig(config);
        final LlmConfig config2 = LlmConfig(
          id: 'cfg2',
          name: 'Second',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        cubit.addLlmConfig(config2);

        cubit.selectLlmConfig('cfg2');

        expect(cubit.state.llmConfigs.selectedConfigId, 'cfg2');
      });
    });

    group('addPrompt', () {
      test('adds prompt and selects it', () {
        cubit.addPrompt('New prompt');

        expect(cubit.state.llmConfigs.prompts, contains('New prompt'));
        expect(cubit.state.llmConfigs.selectedPrompt, 'New prompt');
      });
    });

    group('updatePromptByIndex', () {
      test('updates prompt at given index', () {
        final String original = cubit.state.llmConfigs.prompts.first;

        cubit.updatePromptByIndex('Replaced', 0);

        expect(cubit.state.llmConfigs.prompts.first, 'Replaced');
        expect(cubit.state.llmConfigs.prompts, isNot(contains(original)));
      });
    });

    group('deletePrompt', () {
      test(
        'removes prompt and selects first remaining when deleted was selected',
        () {
          cubit.addPrompt('Extra prompt');
          cubit.selectPrompt('Extra prompt');

          cubit.deletePrompt('Extra prompt');

          expect(
            cubit.state.llmConfigs.prompts,
            isNot(contains('Extra prompt')),
          );
          expect(cubit.state.llmConfigs.selectedPrompt, isNot('Extra prompt'));
        },
      );

      test(
        'removes prompt without changing selection when other is selected',
        () {
          cubit.addPrompt('Extra prompt');
          // Default prompt is still selected

          cubit.deletePrompt('Extra prompt');

          expect(
            cubit.state.llmConfigs.prompts,
            isNot(contains('Extra prompt')),
          );
        },
      );
    });

    group('selectPrompt', () {
      test('updates selected prompt', () {
        final String firstPrompt = cubit.state.llmConfigs.prompts.first;
        cubit.addPrompt('Another prompt');

        cubit.selectPrompt('Another prompt');

        expect(cubit.state.llmConfigs.selectedPrompt, 'Another prompt');

        cubit.selectPrompt(firstPrompt);
        expect(cubit.state.llmConfigs.selectedPrompt, firstPrompt);
      });
    });

    group('duplicatePrompt', () {
      test('creates copy with "(copy)" suffix and selects it', () {
        cubit.addPrompt('My prompt');

        cubit.duplicatePrompt('My prompt');

        expect(cubit.state.llmConfigs.prompts, contains('My prompt (copy)'));
        expect(cubit.state.llmConfigs.selectedPrompt, 'My prompt (copy)');
      });
    });

    group('LlmConfigs.selectedConfig', () {
      test('returns null when no config is selected', () {
        final LlmConfigs configs = cubit.state.llmConfigs;

        expect(configs.selectedConfig, isNull);
      });

      test('returns matching config when selected', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        cubit.addLlmConfig(config);

        expect(cubit.state.llmConfigs.selectedConfig, isNotNull);
        expect(cubit.state.llmConfigs.selectedConfig!.id, 'cfg1');
      });
    });

    group('LlmConfigsState', () {
      test('copyWith preserves values when not specified', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        cubit.addLlmConfig(config);
        final LlmConfigsState originalState = cubit.state;

        cubit.selectLlmConfig('cfg1');

        expect(
          cubit.state.llmConfigs.configs,
          originalState.llmConfigs.configs,
        );
      });
    });

    group('LlmProviderType', () {
      test('should have correct enum values', () {
        expect(LlmProviderType.values, contains(LlmProviderType.remote));
        expect(LlmProviderType.values, contains(LlmProviderType.localMlx));
        expect(LlmProviderType.values.length, 2);
      });

      test('should serialize enum correctly', () {
        const LlmProviderType type = LlmProviderType.remote;
        expect(type.name, 'remote');
      });
    });

    group('LlmConfig', () {
      test('generates id when not provided', () {
        final LlmConfig config = LlmConfig(
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        expect(config.id, isNotEmpty);
      });

      test('uses provided id', () {
        final LlmConfig config = LlmConfig(
          id: 'fixed-id',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        expect(config.id, 'fixed-id');
      });

      test('toJson/fromJson roundtrip', () {
        final LlmConfig config = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          url: 'http://api.example.com',
          model: 'gpt-4',
          apiKey: 'key',
          delay: 500,
          providerType: LlmProviderType.remote,
          mlxPath: '/path/to/mlx',
        );

        final LlmConfig roundtrip = LlmConfig.fromJson(config.toJson());

        expect(roundtrip.id, config.id);
        expect(roundtrip.name, config.name);
        expect(roundtrip.url, config.url);
        expect(roundtrip.model, config.model);
        expect(roundtrip.apiKey, config.apiKey);
        expect(roundtrip.delay, config.delay);
        expect(roundtrip.providerType, config.providerType);
        expect(roundtrip.mlxPath, config.mlxPath);
      });

      test('value equality', () {
        final LlmConfig a = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );
        final LlmConfig b = LlmConfig(
          id: 'cfg1',
          name: 'Test',
          model: 'gpt-4',
          providerType: LlmProviderType.remote,
        );

        expect(a, equals(b));
      });
    });

    group('LlmConfigs', () {
      test('fromJson/toJson roundtrip', () {
        final LlmConfigs configs = LlmConfigs(
          configs: <LlmConfig>[
            LlmConfig(
              id: 'cfg1',
              name: 'Test',
              model: 'gpt-4',
              providerType: LlmProviderType.remote,
            ),
          ],
          prompts: const <String>['prompt1', 'prompt2'],
          selectedConfigId: 'cfg1',
          selectedPrompt: 'prompt1',
        );

        final LlmConfigs roundtrip = LlmConfigs.fromJson(configs.toJson());

        expect(roundtrip.configs.length, 1);
        expect(roundtrip.configs.first.id, 'cfg1');
        expect(roundtrip.prompts, <String>['prompt1', 'prompt2']);
        expect(roundtrip.selectedConfigId, 'cfg1');
        expect(roundtrip.selectedPrompt, 'prompt1');
      });

      test('fromJson handles legacy prompt field', () {
        final Map<String, dynamic> json = <String, dynamic>{
          'configs': <Map<String, dynamic>>[],
          'prompt': 'legacy prompt',
          'selectedConfigId': null,
          'selectedPrompt': null,
        };

        final LlmConfigs configs = LlmConfigs.fromJson(json);

        expect(configs.prompts, <String>['legacy prompt']);
      });

      test('copyWith forceSelectedConfigId sets null', () {
        const LlmConfigs configs = LlmConfigs(
          configs: <LlmConfig>[],
          prompts: <String>[],
          selectedConfigId: 'old',
        );

        final LlmConfigs cleared = configs.copyWith(
          forceSelectedConfigId: true,
        );

        expect(cleared.selectedConfigId, isNull);
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_configs.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/llm_config/data/repositories/llm_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LlmConfigs sampleConfigs() => LlmConfigs(
    configs: <LlmConfig>[
      LlmConfig(
        id: 'a',
        name: 'Remote',
        model: 'gpt-4',
        providerType: LlmProviderType.remote,
        apiKey: 'secret',
      ),
      LlmConfig(
        id: 'b',
        name: 'Local',
        model: 'mlx-model',
        providerType: LlmProviderType.localMlx,
        mlxPath: '/models/foo',
      ),
    ],
    prompts: const <String>['prompt one', 'prompt two'],
    selectedConfigId: 'a',
    selectedPrompt: 'prompt one',
    ideogramJsonEnabled: true,
  );

  group('LlmConfigService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('loadLlmConfigs returns null when nothing stored', () async {
      final LlmConfigs? result = await LlmConfigService.loadLlmConfigs();
      expect(result, isNull);
    });

    test('save then load round-trips the full config', () async {
      final LlmConfigs original = sampleConfigs();

      await LlmConfigService.saveLlmConfigs(original);
      final LlmConfigs? loaded = await LlmConfigService.loadLlmConfigs();

      expect(loaded, isNotNull);
      expect(loaded!.configs.length, 2);
      expect(loaded.configs.first.id, 'a');
      expect(loaded.configs.first.apiKey, 'secret');
      expect(loaded.configs.last.providerType, LlmProviderType.localMlx);
      expect(loaded.prompts, <String>['prompt one', 'prompt two']);
      expect(loaded.selectedConfigId, 'a');
      expect(loaded.selectedPrompt, 'prompt one');
      expect(loaded.ideogramJsonEnabled, true);
    });

    test('overwrite replaces previously stored config', () async {
      await LlmConfigService.saveLlmConfigs(sampleConfigs());

      const LlmConfigs replacement = LlmConfigs(
        configs: <LlmConfig>[],
        prompts: <String>['only'],
      );
      await LlmConfigService.saveLlmConfigs(replacement);

      final LlmConfigs? loaded = await LlmConfigService.loadLlmConfigs();
      expect(loaded, isNotNull);
      expect(loaded!.configs, isEmpty);
      expect(loaded.prompts, <String>['only']);
    });
  });
}

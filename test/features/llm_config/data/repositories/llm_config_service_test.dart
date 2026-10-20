import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/models/llm_configs.dart';
import 'package:yofardev_captioner/core/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/llm_config/data/repositories/llm_config_service.dart';

/// Store whose reads and writes always throw — used to exercise the failure
/// mapping paths of [LlmConfigService].
class ThrowingPreferencesStore implements SharedPreferencesStorePlatform {
  @override
  bool get isMock => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw Exception('store down');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final LlmConfigService llmConfigService = LlmConfigService();

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
      final GetIt locator = GetIt.instance;
      if (!locator.isRegistered<Logger>()) {
        locator.registerLazySingleton<Logger>(() => Logger('Test'));
      }
    });

    test('loadLlmConfigs returns Right(null) when nothing stored', () async {
      final Either<Failure, LlmConfigs?> result = await llmConfigService
          .loadLlmConfigs();
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable(), isNull);
    });

    test('save then load round-trips the full config', () async {
      final LlmConfigs original = sampleConfigs();

      await llmConfigService.saveLlmConfigs(original);
      final Either<Failure, LlmConfigs?> loaded = await llmConfigService
          .loadLlmConfigs();

      final LlmConfigs? configs = loaded.getRight().toNullable();
      expect(configs, isNotNull);
      expect(configs!.configs.length, 2);
      expect(configs.configs.first.id, 'a');
      expect(configs.configs.first.apiKey, 'secret');
      expect(configs.configs.last.providerType, LlmProviderType.localMlx);
      expect(configs.prompts, <String>['prompt one', 'prompt two']);
      expect(configs.selectedConfigId, 'a');
      expect(configs.selectedPrompt, 'prompt one');
      expect(configs.ideogramJsonEnabled, true);
    });

    test('overwrite replaces previously stored config', () async {
      await llmConfigService.saveLlmConfigs(sampleConfigs());

      const LlmConfigs replacement = LlmConfigs(
        configs: <LlmConfig>[],
        prompts: <String>['only'],
      );
      await llmConfigService.saveLlmConfigs(replacement);

      final Either<Failure, LlmConfigs?> loaded = await llmConfigService
          .loadLlmConfigs();
      final LlmConfigs? configs = loaded.getRight().toNullable();
      expect(configs, isNotNull);
      expect(configs!.configs, isEmpty);
      expect(configs.prompts, <String>['only']);
    });

    group('failure mapping', () {
      tearDown(() {
        SharedPreferencesStorePlatform.instance =
            InMemorySharedPreferencesStore.empty();
      });

      test(
        'malformed stored JSON maps to Failure.invalidData (known mapping)',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            'flutter.llm_configs': 'not-json{',
          });

          final Either<Failure, LlmConfigs?> result = await llmConfigService
              .loadLlmConfigs();

          final Failure? failure = result.getLeft().toNullable();
          expect(failure, isA<FailureInvalidData>());
        },
      );

      test(
        'stored JSON of the wrong shape maps to Failure.invalidData',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            'flutter.llm_configs': '["a", "b"]',
          });

          final Either<Failure, LlmConfigs?> result = await llmConfigService
              .loadLlmConfigs();

          final Failure? failure = result.getLeft().toNullable();
          expect(failure, isA<FailureInvalidData>());
        },
      );

      test('store throwing on read maps to Failure.unexpected', () async {
        SharedPreferencesStorePlatform.instance = ThrowingPreferencesStore();

        final Either<Failure, LlmConfigs?> result = await llmConfigService
            .loadLlmConfigs();

        final Failure? failure = result.getLeft().toNullable();
        expect(failure, isA<FailureUnexpected>());
      });

      test('store throwing on write maps to Failure.unexpected', () async {
        SharedPreferencesStorePlatform.instance = ThrowingPreferencesStore();

        final Either<Failure, void> result = await llmConfigService
            .saveLlmConfigs(sampleConfigs());

        final Failure? failure = result.getLeft().toNullable();
        expect(failure, isA<FailureUnexpected>());
      });
    });
  });
}

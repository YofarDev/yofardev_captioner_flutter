import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/features/llm_config/logic/llm_configs_cubit.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_configs.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';

@GenerateMocks(<Type>[])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LlmConfigsCubit', () {
    late LlmConfigsCubit llmConfigsCubit;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      llmConfigsCubit = LlmConfigsCubit();
    });

    tearDown(() {
      llmConfigsCubit.close();
    });

    test('should instantiate cubit', () {
      expect(llmConfigsCubit, isNotNull);
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
  });
}

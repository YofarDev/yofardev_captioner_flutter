import '../../../../core/models/llm_configs.dart';

/// Contract for persisting and loading the user's LLM configurations.
abstract class ILlmConfigRepository {
  /// Saves [configs], replacing any previously persisted configuration set.
  Future<void> saveLlmConfigs(LlmConfigs configs);

  /// Loads the persisted configurations, or null when none were saved yet.
  Future<LlmConfigs?> loadLlmConfigs();
}

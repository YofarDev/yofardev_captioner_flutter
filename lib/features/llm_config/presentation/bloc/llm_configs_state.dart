part of 'llm_configs_cubit.dart';

class LlmConfigsState extends Equatable {
  final LlmConfigs llmConfigs;

  /// User-facing message for the last repository failure, if any. Clearable
  /// via `copyWith(clearError: true)` so errors never go stale.
  final String? error;

  const LlmConfigsState({
    this.llmConfigs = const LlmConfigs.defaults(),
    this.error,
  });

  @override
  List<Object?> get props => <Object?>[llmConfigs, error];

  LlmConfigsState copyWith({
    LlmConfigs? llmConfigs,
    bool clearError = false,
    String? error,
  }) {
    return LlmConfigsState(
      llmConfigs: llmConfigs ?? this.llmConfigs,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

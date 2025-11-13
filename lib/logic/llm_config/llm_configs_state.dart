part of 'llm_configs_cubit.dart';

class LlmConfigsState extends Equatable {
  final LlmConfigs llmConfigs;
  const LlmConfigsState({
    this.llmConfigs = const LlmConfigs(
      configs: <LlmConfig>[],
      prompt:
          'Describe this image as one paragraph. Do not describe the atmosphere.',
    ),
  });
  @override
  List<Object> get props => <Object>[llmConfigs];
  LlmConfigsState copyWith({LlmConfigs? llmConfigs}) {
    return LlmConfigsState(llmConfigs: llmConfigs ?? this.llmConfigs);
  }
}

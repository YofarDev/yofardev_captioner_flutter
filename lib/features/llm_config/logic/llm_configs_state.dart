part of 'llm_configs_cubit.dart';

const String _kDefaultPrompt1 =
    'Describe this image as one paragraph. Do not describe the atmosphere.';
const String _kDefaultPrompt2 =
    'Describe this image as a list of keywords, separated by commas.';

class LlmConfigsState extends Equatable {
  final LlmConfigs llmConfigs;
  const LlmConfigsState({
    this.llmConfigs = const LlmConfigs(
      configs: <LlmConfig>[],
      prompts: <String>[_kDefaultPrompt1, _kDefaultPrompt2],
      selectedPrompt: _kDefaultPrompt1,
    ),
  });
  @override
  List<Object> get props => <Object>[llmConfigs];
  LlmConfigsState copyWith({LlmConfigs? llmConfigs}) {
    return LlmConfigsState(llmConfigs: llmConfigs ?? this.llmConfigs);
  }
}

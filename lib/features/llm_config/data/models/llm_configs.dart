import 'package:equatable/equatable.dart';

import 'llm_config.dart';

class LlmConfigs extends Equatable {
  final List<LlmConfig> configs;
  final List<String> prompts;
  final String? selectedConfigId;
  final String? selectedPrompt;

  const LlmConfigs({
    required this.configs,
    required this.prompts,
    this.selectedConfigId,
    this.selectedPrompt,
  });

  @override
  List<Object?> get props => <Object?>[
    configs,
    prompts,
    selectedConfigId,
    selectedPrompt,
  ];

  LlmConfigs copyWith({
    List<LlmConfig>? configs,
    List<String>? prompts,
    String? selectedConfigId,
    String? selectedPrompt,
    bool forceSelectedConfigId = false,
  }) {
    return LlmConfigs(
      configs: configs ?? this.configs,
      prompts: prompts ?? this.prompts,
      selectedConfigId: forceSelectedConfigId
          ? selectedConfigId
          : selectedConfigId ?? this.selectedConfigId,
      selectedPrompt: selectedPrompt ?? this.selectedPrompt,
    );
  }

  factory LlmConfigs.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? prompts = json['prompts'] as List<dynamic>?;
    return LlmConfigs(
      configs: (json['configs'] as List<dynamic>)
          .map((dynamic e) => LlmConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      prompts: prompts != null
          ? prompts.map((dynamic e) => e as String).toList()
          : <String>[json['prompt'] as String],
      selectedConfigId: json['selectedConfigId'] as String?,
      selectedPrompt: json['selectedPrompt'] as String?,
    );
  }
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'configs': configs.map((LlmConfig e) => e.toJson()).toList(),
      'prompts': prompts,
      'selectedConfigId': selectedConfigId,
      'selectedPrompt': selectedPrompt,
    };
  }

  LlmConfig? get selectedConfig {
    if (selectedConfigId == null) {
      return null;
    }
    return configs.firstWhere(
      (LlmConfig element) => element.id == selectedConfigId,
    );
  }
}

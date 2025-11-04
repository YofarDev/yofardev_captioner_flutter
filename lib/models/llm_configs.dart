import 'package:equatable/equatable.dart';

import 'llm_config.dart';

class LlmConfigs extends Equatable {
  final List<LlmConfig> configs;
  final String prompt;
  final String? selectedConfigId;

  const LlmConfigs({
    required this.configs,
    required this.prompt,
    this.selectedConfigId,
  });

  @override
  List<Object?> get props => <Object?>[configs, prompt, selectedConfigId];

  LlmConfigs copyWith({
    List<LlmConfig>? configs,
    String? prompt,
    String? selectedConfigId,
    bool forceSelectedConfigId = false,
  }) {
    return LlmConfigs(
      configs: configs ?? this.configs,
      prompt: prompt ?? this.prompt,
      selectedConfigId: forceSelectedConfigId
          ? selectedConfigId
          : selectedConfigId ?? this.selectedConfigId,
    );
  }

  factory LlmConfigs.fromJson(Map<String, dynamic> json) {
    return LlmConfigs(
      configs: (json['configs'] as List<dynamic>)
          .map((dynamic e) => LlmConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      prompt: json['prompt'] as String,
      selectedConfigId: json['selectedConfigId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'configs': configs.map((LlmConfig e) => e.toJson()).toList(),
      'prompt': prompt,
      'selectedConfigId': selectedConfigId,
    };
  }

  LlmConfig? get selectedConfig {
    return configs.firstWhere(
      (LlmConfig element) => element.id == selectedConfigId,
    );
  }
}

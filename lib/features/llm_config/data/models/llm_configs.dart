import 'package:equatable/equatable.dart';

import 'llm_config.dart';
import 'structured_batch_overrides.dart';

class LlmConfigs extends Equatable {
  final List<LlmConfig> configs;
  final List<String> prompts;
  final String? selectedConfigId;
  final String? selectedPrompt;

  /// When true, the Run button uses the Ideogram4 structured JSON pipeline.
  final bool ideogramJsonEnabled;

  /// When true, structured captioning saves prompt, VLM response, and bbox
  /// images alongside each image for debugging.
  final bool debugMode;

  /// When true, the structured pipeline skips SAM detection and uses the
  /// VLM-provided bboxes directly.
  final bool disableSam;

  final StructuredBatchOverrides structuredBatchOverrides;

  const LlmConfigs({
    required this.configs,
    required this.prompts,
    this.selectedConfigId,
    this.selectedPrompt,
    this.ideogramJsonEnabled = false,
    this.debugMode = false,
    this.disableSam = false,
    this.structuredBatchOverrides = const StructuredBatchOverrides(),
  });

  @override
  List<Object?> get props => <Object?>[
    configs,
    prompts,
    selectedConfigId,
    selectedPrompt,
    ideogramJsonEnabled,
    debugMode,
    disableSam,
    structuredBatchOverrides,
  ];

  LlmConfigs copyWith({
    List<LlmConfig>? configs,
    List<String>? prompts,
    String? selectedConfigId,
    String? selectedPrompt,
    bool forceSelectedConfigId = false,
    bool? ideogramJsonEnabled,
    bool? debugMode,
    bool? disableSam,
    StructuredBatchOverrides? structuredBatchOverrides,
  }) {
    return LlmConfigs(
      configs: configs ?? this.configs,
      prompts: prompts ?? this.prompts,
      selectedConfigId: forceSelectedConfigId
          ? selectedConfigId
          : selectedConfigId ?? this.selectedConfigId,
      selectedPrompt: selectedPrompt ?? this.selectedPrompt,
      ideogramJsonEnabled: ideogramJsonEnabled ?? this.ideogramJsonEnabled,
      debugMode: debugMode ?? this.debugMode,
      disableSam: disableSam ?? this.disableSam,
      structuredBatchOverrides:
          structuredBatchOverrides ?? this.structuredBatchOverrides,
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
      ideogramJsonEnabled: json['ideogramJsonEnabled'] as bool? ?? false,
      debugMode: json['debugMode'] as bool? ?? false,
      disableSam: json['disableSam'] as bool? ?? false,
      structuredBatchOverrides: StructuredBatchOverrides.fromJson(
        json['structuredBatchOverrides'] as Map<String, dynamic>? ??
            <String, dynamic>{},
      ),
    );
  }
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'configs': configs.map((LlmConfig e) => e.toJson()).toList(),
      'prompts': prompts,
      'selectedConfigId': selectedConfigId,
      'selectedPrompt': selectedPrompt,
      'ideogramJsonEnabled': ideogramJsonEnabled,
      'debugMode': debugMode,
      'disableSam': disableSam,
      'structuredBatchOverrides': structuredBatchOverrides.toJson(),
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

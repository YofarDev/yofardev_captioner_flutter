import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/llm_config.dart';
import '../../../core/models/llm_configs.dart';
import '../../../core/models/llm_provider_type.dart';
import '../../../core/models/structured_batch_overrides.dart';
import '../data/repositories/llm_config_service.dart';

part 'llm_configs_state.dart';

/// A Cubit that manages the state of LLM (Large Language Model) configurations.
///
/// This includes loading, adding, updating, deleting, and selecting LLM configurations.
class LlmConfigsCubit extends Cubit<LlmConfigsState> {
  /// Creates an [LlmConfigsCubit] with an initial [LlmConfigsState].
  LlmConfigsCubit({LlmConfigService? llmConfigService})
    : _llmConfigService = llmConfigService ?? LlmConfigService(),
      super(const LlmConfigsState());

  final LlmConfigService _llmConfigService;

  /// Initializes the cubit by loading saved LLM configurations.
  ///
  /// If configurations are found, it emits a new state with the loaded
  /// configurations. Otherwise it defaults to an empty, unsaved configuration
  /// (plus a local MLX suggestion on macOS).
  void onInit() async {
    final LlmConfigs? configs = await _llmConfigService.loadLlmConfigs();
    if (configs != null) {
      emit(state.copyWith(llmConfigs: configs));
    } else if (Platform.isMacOS) {
      final LlmConfig localConfig = LlmConfig(
        id: 'Qwen3-VL-4B-Instruct-5bit',
        name: 'Qwen3-VL-4B-Instruct-5bit',
        providerType: LlmProviderType.localMlx,
        model: 'mlx-community/Qwen3-VL-4B-Instruct-5bit',
      );
      addLlmConfig(localConfig);
    }
  }

  /// Adds a new [LlmConfig] to the list of configurations.
  ///
  /// If no configuration is currently selected, the newly added config becomes the selected one.
  /// The updated configurations are then saved.
  void addLlmConfig(LlmConfig config) {
    final List<LlmConfig> newConfigs = <LlmConfig>[
      ...state.llmConfigs.configs,
      config,
    ];
    final String? newSelectedConfigId = state.llmConfigs.selectedConfigId;
    if (newSelectedConfigId == null) {
      emit(
        state.copyWith(
          llmConfigs: state.llmConfigs.copyWith(
            configs: newConfigs,
            selectedConfigId: config.id,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          llmConfigs: state.llmConfigs.copyWith(configs: newConfigs),
        ),
      );
    }
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Updates an existing [LlmConfig] in the list of configurations.
  ///
  /// The configuration is identified by its ID. The updated configurations are then saved.
  void updateLlmConfig(LlmConfig config) {
    final List<LlmConfig> newConfigs = state.llmConfigs.configs
        .map((LlmConfig c) => c.id == config.id ? config : c)
        .toList();
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(configs: newConfigs),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Deletes an [LlmConfig] with the given [id] from the list of configurations.
  ///
  /// If the deleted configuration was the selected one, the selected configuration is reset.
  /// The updated configurations are then saved.
  void deleteLlmConfig(String id) {
    final List<LlmConfig> newConfigs = state.llmConfigs.configs
        .where((LlmConfig c) => c.id != id)
        .toList();
    if (state.llmConfigs.selectedConfigId == id) {
      emit(
        state.copyWith(
          llmConfigs: state.llmConfigs.copyWith(
            configs: newConfigs,
            forceSelectedConfigId: true,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          llmConfigs: state.llmConfigs.copyWith(configs: newConfigs),
        ),
      );
    }
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Duplicates an existing [LlmConfig] with the given [id].
  ///
  /// Creates a copy of the configuration with a new ID and adds it to the list.
  void duplicateLlmConfig(String id) {
    final LlmConfig configToDuplicate = state.llmConfigs.configs.firstWhere(
      (LlmConfig c) => c.id == id,
    );

    final LlmConfig duplicatedConfig = LlmConfig(
      name: '${configToDuplicate.name} (copy)',
      url: configToDuplicate.url,
      model: configToDuplicate.model,
      apiKey: configToDuplicate.apiKey,
      delay: configToDuplicate.delay,
      providerType: configToDuplicate.providerType,
      mlxPath: configToDuplicate.mlxPath,
    );

    final List<LlmConfig> newConfigs = <LlmConfig>[
      ...state.llmConfigs.configs,
      duplicatedConfig,
    ];

    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(
          configs: newConfigs,
          selectedConfigId: duplicatedConfig.id,
        ),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Selects an [LlmConfig] with the given [id] as the active configuration.
  ///
  /// The updated configurations are then saved.
  void selectLlmConfig(String id) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(selectedConfigId: id),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void addPrompt(String prompt) {
    final List<String> newPrompts = <String>[
      ...state.llmConfigs.prompts,
      prompt,
    ];
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(
          prompts: newPrompts,
          selectedPrompt: prompt,
        ),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void updatePromptByIndex(String prompt, int index) {
    final List<String> newPrompts = <String>[...state.llmConfigs.prompts];
    final String oldPrompt = newPrompts[index];
    newPrompts[index] = prompt;
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(
          prompts: newPrompts,
          selectedPrompt: oldPrompt == state.llmConfigs.selectedPrompt
              ? prompt
              : state.llmConfigs.selectedPrompt,
        ),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void deletePrompt(String prompt) {
    final List<String> newPrompts = state.llmConfigs.prompts
        .where((String p) => p != prompt)
        .toList();
    if (state.llmConfigs.selectedPrompt == prompt) {
      emit(
        state.copyWith(
          llmConfigs: state.llmConfigs.copyWith(
            prompts: newPrompts,
            selectedPrompt: newPrompts.first,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          llmConfigs: state.llmConfigs.copyWith(prompts: newPrompts),
        ),
      );
    }
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void selectPrompt(String prompt) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(selectedPrompt: prompt),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Duplicates an existing prompt.
  ///
  /// Creates a copy of the prompt with "(copy)" appended and adds it to the list.
  void duplicatePrompt(String prompt) {
    final String duplicatedPrompt = '$prompt (copy)';
    final List<String> newPrompts = <String>[
      ...state.llmConfigs.prompts,
      duplicatedPrompt,
    ];
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(
          prompts: newPrompts,
          selectedPrompt: duplicatedPrompt,
        ),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Toggles the Ideogram JSON structured captioning mode.
  void setIdeogramJsonEnabled(bool enabled) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(ideogramJsonEnabled: enabled),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Toggles debug artifact saving for structured captioning.
  void setDebugMode(bool enabled) {
    emit(
      state.copyWith(llmConfigs: state.llmConfigs.copyWith(debugMode: enabled)),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Toggles SAM detection off in the structured pipeline.
  void setDisableSam(bool enabled) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(disableSam: enabled),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Sets whether the configured VLM emits `[x1,y1,x2,y2]` (xyxy, the common
  /// default) or obeys the yxyx instruction. The prompt and the bbox
  /// normalizer both follow this flag; the stored Ideogram4 JSON stays yxyx.
  void setVlmEmitsXyxy(bool enabled) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(vlmEmitsXyxy: enabled),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Sets whether the structured pipeline runs in multi-stage mode (enumerate
  /// + per-element enrich) instead of single-shot.
  void setMultiStage(bool enabled) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(multiStage: enabled),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  /// Updates the structured batch overrides for the JSON captioning pipeline.
  void updateStructuredBatchOverrides(StructuredBatchOverrides overrides) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(
          structuredBatchOverrides: overrides,
        ),
      ),
    );
    _llmConfigService.saveLlmConfigs(state.llmConfigs);
  }
}

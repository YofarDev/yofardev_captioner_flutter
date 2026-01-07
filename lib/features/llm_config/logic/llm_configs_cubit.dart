import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/llm_config.dart';
import '../data/models/llm_configs.dart';
import '../data/models/llm_provider_type.dart';
import '../data/repositories/llm_config_service.dart';

part 'llm_configs_state.dart';

/// A Cubit that manages the state of LLM (Large Language Model) configurations.
///
/// This includes loading, adding, updating, deleting, and selecting LLM configurations.
class LlmConfigsCubit extends Cubit<LlmConfigsState> {
  /// Creates an [LlmConfigsCubit] with an initial [LlmConfigsState].
  LlmConfigsCubit() : super(const LlmConfigsState());

  /// Initializes the cubit by loading saved LLM configurations.
  ///
  /// If configurations are found, it emits a new state with the loaded configurations.
  void onInit() async {
    final LlmConfigs? configs = await LlmConfigService.loadLlmConfigs();
    if (configs != null) {
      emit(state.copyWith(llmConfigs: configs));
    } else {
      if (Platform.isMacOS) {
        final LlmConfig config = LlmConfig(
          id: 'Qwen3-VL-4B-Instruct-5bit',
          name: 'Qwen3-VL-4B-Instruct-5bit',
          providerType: LlmProviderType.localMlx,
          model: 'mlx-community/Qwen3-VL-4B-Instruct-5bit',
        );
        addLlmConfig(config);
      }
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
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
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
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
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
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
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
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
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
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void updatePromptByIndex(String prompt, int index) {
    final List<String> newPrompts = <String>[...state.llmConfigs.prompts];
    newPrompts[index] = prompt;
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(prompts: newPrompts),
      ),
    );
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
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
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void selectPrompt(String prompt) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(selectedPrompt: prompt),
      ),
    );
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
  }
}

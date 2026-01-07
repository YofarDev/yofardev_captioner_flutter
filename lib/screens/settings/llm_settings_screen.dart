import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/llm_config/llm_configs_cubit.dart';
import '../../models/llm_config.dart';
import '../../models/llm_provider_type.dart';
import '../../../core/constants/app_colors.dart';

class LlmSettingsScreen extends StatefulWidget {
  const LlmSettingsScreen({super.key});
  @override
  State<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends State<LlmSettingsScreen> {
  Future<void> _showConfigDialog([LlmConfig? config]) async {
    final bool isEditing = config != null;
    final TextEditingController nameController = TextEditingController(
      text: config?.name,
    );
    final TextEditingController urlController = TextEditingController(
      text: config?.url,
    );
    final TextEditingController modelController = TextEditingController(
      text: config?.model,
    );
    final TextEditingController apiKeyController = TextEditingController(
      text: config?.apiKey,
    );
    final TextEditingController delayController = TextEditingController(
      text: config?.delay.toString() ?? '0',
    );
    final TextEditingController mlxPathController = TextEditingController(
      text: config?.mlxPath,
    );

    LlmProviderType selectedProviderType =
        config?.providerType ?? LlmProviderType.remote;

    // Pre-fill model for macOS users when adding a new local config
    if (!isEditing &&
        Platform.isMacOS &&
        selectedProviderType == LlmProviderType.localMlx) {
      modelController.text = 'mlx-community/Qwen3-VL-4B-Instruct-5bit';
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: <Widget>[
              Icon(isEditing ? Icons.edit_note : Icons.add_circle_outline),
              const SizedBox(width: 8),
              Text(isEditing ? 'Edit Configuration' : 'Add Configuration'),
            ],
          ),
          content: StatefulBuilder(
            builder:
                (
                  BuildContext context,
                  void Function(void Function()) setState,
                ) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<LlmProviderType>(
                          initialValue: selectedProviderType,
                          onChanged: (LlmProviderType? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedProviderType = newValue;
                                // Pre-fill model for macOS users when switching to local
                                if (!isEditing &&
                                    Platform.isMacOS &&
                                    selectedProviderType ==
                                        LlmProviderType.localMlx) {
                                  modelController.text =
                                      'mlx-community/Qwen3-VL-4B-Instruct-5bit';
                                }
                              });
                            }
                          },
                          items: LlmProviderType.values.map((
                            LlmProviderType provider,
                          ) {
                            return DropdownMenuItem<LlmProviderType>(
                              value: provider,
                              child: Text(provider.name),
                            );
                          }).toList(),
                          decoration: const InputDecoration(
                            labelText: 'Provider Type',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (selectedProviderType == LlmProviderType.remote)
                          _buildTextField(nameController, 'Name', Icons.label),
                        if (selectedProviderType ==
                            LlmProviderType.remote) ...<Widget>[
                          _buildTextField(urlController, 'URL', Icons.link),
                          _buildTextField(
                            apiKeyController,
                            'API Key',
                            Icons.vpn_key,
                          ),
                        ],
                        _buildTextField(
                          modelController,
                          'Model',
                          Icons.psychology,
                        ),
                        if (selectedProviderType == LlmProviderType.localMlx)
                          _buildTextField(
                            mlxPathController,
                            'Executable Path (optional)',
                            Icons.terminal,
                          ),
                        if (selectedProviderType == LlmProviderType.remote)
                          _buildTextField(
                            delayController,
                            'Delay (ms)',
                            Icons.timer,
                            inputType: TextInputType.number,
                          ),
                      ],
                    ),
                  );
                },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final bool isLocal =
                    selectedProviderType == LlmProviderType.localMlx;
                final LlmConfig newConfig = LlmConfig(
                  id: config?.id,
                  name: isLocal
                      ? modelController.text.split('/').last
                      : nameController.text,
                  url: isLocal ? null : urlController.text,
                  model: modelController.text,
                  apiKey: isLocal ? null : apiKeyController.text,
                  delay: isLocal ? 0 : int.tryParse(delayController.text) ?? 0,
                  providerType: selectedProviderType,
                  mlxPath: isLocal ? mlxPathController.text : null,
                );
                if (isEditing) {
                  context.read<LlmConfigsCubit>().updateLlmConfig(newConfig);
                } else {
                  context.read<LlmConfigsCubit>().addLlmConfig(newConfig);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPromptDialog({String? oldPrompt, int? index}) async {
    final bool isEditing = oldPrompt != null;
    final TextEditingController promptController = TextEditingController(
      text: oldPrompt,
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: <Widget>[
              Icon(isEditing ? Icons.edit_note : Icons.playlist_add),
              const SizedBox(width: 8),
              Text(isEditing ? 'Edit Prompt' : 'Add Prompt'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 8),
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    labelText: 'Prompt',
                    hintText: 'You are a helpful assistant...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  minLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String newPrompt = promptController.text;
                if (newPrompt.isNotEmpty) {
                  if (isEditing) {
                    context.read<LlmConfigsCubit>().updatePromptByIndex(
                      newPrompt,
                      index!,
                    );
                  } else {
                    context.read<LlmConfigsCubit>().addPrompt(newPrompt);
                  }
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        title: const Text('LLM Settings'),
        centerTitle: true,
        backgroundColor: darkGrey,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
        builder: (BuildContext context, LlmConfigsState state) {
          return SafeArea(
            child: Column(
              children: <Widget>[
                _buildSectionHeader(
                  context,
                  title: "Vision Models",
                  icon: Icons.settings_input_component,
                  onAdd: () => _showConfigDialog(),
                ),
                Expanded(
                  flex: 5,
                  child: state.llmConfigs.configs.isEmpty
                      ? _buildEmptyState("No models configured yet.")
                      : RadioGroup<String?>(
                          groupValue: state.llmConfigs.selectedConfigId,
                          onChanged: (String? val) {
                            if (val != null) {
                              context.read<LlmConfigsCubit>().selectLlmConfig(
                                val,
                              );
                            }
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: state.llmConfigs.configs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (BuildContext context, int index) {
                              final LlmConfig config =
                                  state.llmConfigs.configs[index];
                              final bool isSelected =
                                  config.id ==
                                  state.llmConfigs.selectedConfigId;

                              return _buildConfigCard(
                                config: config,
                                isSelected: isSelected,
                                onTap: () => context
                                    .read<LlmConfigsCubit>()
                                    .selectLlmConfig(config.id),
                                onEdit: () => _showConfigDialog(config),
                                onDelete: () => context
                                    .read<LlmConfigsCubit>()
                                    .deleteLlmConfig(config.id),
                              );
                            },
                          ),
                        ),
                ),
                const Divider(height: 1, thickness: 1),
                _buildSectionHeader(
                  context,
                  title: "Prompts",
                  icon: Icons.chat_bubble_outline,
                  onAdd: () => _showPromptDialog(),
                ),
                Expanded(
                  flex: 4,
                  child: state.llmConfigs.prompts.isEmpty
                      ? _buildEmptyState("No prompts added yet.")
                      : RadioGroup<String>(
                          groupValue: state.llmConfigs.selectedPrompt,
                          onChanged: (String? val) {
                            if (val != null) {
                              context.read<LlmConfigsCubit>().selectPrompt(val);
                            }
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: state.llmConfigs.prompts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (BuildContext context, int index) {
                              final String prompt =
                                  state.llmConfigs.prompts[index];
                              final bool isSelected =
                                  prompt == state.llmConfigs.selectedPrompt;

                              return _buildPromptCard(
                                prompt: prompt,
                                isSelected: isSelected,
                                onTap: () => context
                                    .read<LlmConfigsCubit>()
                                    .selectPrompt(prompt),
                                onEdit: () => _showPromptDialog(
                                  oldPrompt: prompt,
                                  index: index,
                                ),
                                onDelete: () => context
                                    .read<LlmConfigsCubit>()
                                    .deletePrompt(prompt),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onAdd,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      color: lightGrey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          IconButton.filledTonal(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            tooltip: "Add New",
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.inbox, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildConfigCard({
    required LlmConfig config,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? lightPink.withAlpha(100) : Colors.grey[700],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: <Widget>[
              Radio<String?>(value: config.id),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      config.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${config.model} • ${config.providerType.name}${config.providerType == LlmProviderType.remote ? " • ${config.url}" : ""}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildActionButtons(onEdit, onDelete),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard({
    required String prompt,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? lightPink.withAlpha(100) : Colors.grey[700],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: <Widget>[
              Radio<String>(value: prompt),
              Expanded(
                child: Text(
                  prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              _buildActionButtons(onEdit, onDelete),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(VoidCallback onEdit, VoidCallback onDelete) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: onEdit,
          color: Colors.white54,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(8),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
          color: Colors.red[900],
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(8),
        ),
      ],
    );
  }
}

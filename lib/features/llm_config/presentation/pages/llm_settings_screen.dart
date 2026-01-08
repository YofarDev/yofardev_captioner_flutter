import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/radio_group.dart';
import '../../data/models/llm_config.dart';
import '../../data/models/llm_provider_type.dart';
import '../../logic/llm_configs_cubit.dart';

class LlmSettingsScreen extends StatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  State<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends State<LlmSettingsScreen> {
  final ScrollController _modelsScrollController = ScrollController();
  final ScrollController _promptsScrollController = ScrollController();

  @override
  void dispose() {
    _modelsScrollController.dispose();
    _promptsScrollController.dispose();
    super.dispose();
  }

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
                          _buildTextField(
                            nameController,
                            'Name',
                            Icons.label,
                            autofocus: !isEditing,
                          ),
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
                          autofocus:
                              selectedProviderType ==
                                  LlmProviderType.localMlx &&
                              !isEditing,
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
                  // Scroll to the new item
                  _scrollToBottom(_modelsScrollController);
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
                  autofocus: true,
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
                    // Scroll to the new item
                    _scrollToBottom(_promptsScrollController);
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

  void _scrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        autofocus: autofocus,
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
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Use a more space-efficient layout for smaller screens
                final bool useCompactLayout = constraints.maxHeight < 600;

                return Column(
                  children: <Widget>[
                    _buildSectionHeader(
                      context,
                      title: "Vision Models",
                      icon: Icons.settings_input_component,
                      onAdd: () => _showConfigDialog(),
                      count: state.llmConfigs.configs.length,
                    ),
                    Expanded(
                      flex: useCompactLayout ? 4 : 5,
                      child: state.llmConfigs.configs.isEmpty
                          ? _buildEmptyState("No models configured yet.")
                          : _buildModelsList(state),
                    ),
                    Divider(height: 1, thickness: 1, color: Colors.grey[800]),
                    _buildSectionHeader(
                      context,
                      title: "Prompts",
                      icon: Icons.chat_bubble_outline,
                      onAdd: () => _showPromptDialog(),
                      count: state.llmConfigs.prompts.length,
                    ),
                    Expanded(
                      flex: useCompactLayout ? 3 : 4,
                      child: state.llmConfigs.prompts.isEmpty
                          ? _buildEmptyState("No prompts added yet.")
                          : _buildPromptsList(state),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildModelsList(LlmConfigsState state) {
    return CustomRadioGroup<String?>(
      groupValue: state.llmConfigs.selectedConfigId,
      onChanged: (String? val) {
        if (val != null) {
          context.read<LlmConfigsCubit>().selectLlmConfig(val);
        }
      },
      child: ListView.separated(
        controller: _modelsScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: state.llmConfigs.configs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final LlmConfig config = state.llmConfigs.configs[index];
          final bool isSelected =
              config.id == state.llmConfigs.selectedConfigId;

          return _buildConfigCard(
            config: config,
            state: state,
            isSelected: isSelected,
            onTap: () =>
                context.read<LlmConfigsCubit>().selectLlmConfig(config.id),
            onEdit: () => _showConfigDialog(config),
            onDelete: () =>
                context.read<LlmConfigsCubit>().deleteLlmConfig(config.id),
          );
        },
      ),
    );
  }

  Widget _buildPromptsList(LlmConfigsState state) {
    return CustomRadioGroup<String>(
      groupValue: state.llmConfigs.selectedPrompt,
      onChanged: (String? val) {
        if (val != null) {
          context.read<LlmConfigsCubit>().selectPrompt(val);
        }
      },
      child: ListView.separated(
        controller: _promptsScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: state.llmConfigs.prompts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final String prompt = state.llmConfigs.prompts[index];
          final bool isSelected = prompt == state.llmConfigs.selectedPrompt;

          return _buildPromptCard(
            prompt: prompt,
            state: state,
            isSelected: isSelected,
            onTap: () => context.read<LlmConfigsCubit>().selectPrompt(prompt),
            onEdit: () => _showPromptDialog(oldPrompt: prompt, index: index),
            onDelete: () =>
                context.read<LlmConfigsCubit>().deletePrompt(prompt),
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
    int count = 0,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      color: lightGrey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              if (count > 0) ...<Widget>[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lightPink.withAlpha(120),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          IconButton.filledTonal(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 22),
            tooltip: "Add New",
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(10),
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
          Icon(Icons.inbox, size: 56, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard({
    required LlmConfig config,
    required LlmConfigsState state,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: isSelected ? 4 : 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: lightPink, width: 2.5)
            : BorderSide(color: Colors.grey[700]!),
      ),
      color: isSelected ? lightPink.withAlpha(100) : Colors.grey[900],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Transform.scale(
                scale: 0.9,
                child: Radio<String>(
                  // ignore: deprecated_member_use
                  value: config.id,
                  // ignore: deprecated_member_use
                  groupValue: state.llmConfigs.selectedConfigId,
                  // ignore: deprecated_member_use
                  onChanged: (_) => onTap(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.comfortable,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      config.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.model,
                      style: TextStyle(color: Colors.grey[300], fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: <Widget>[
                        _buildProviderChip(config.providerType.name),
                        if (config.providerType == LlmProviderType.remote &&
                            config.url != null)
                          _buildInfoChip(Icons.link, config.url!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildActionButtons(onEdit, onDelete),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptCard({
    required String prompt,
    required LlmConfigsState state,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: isSelected ? 4 : 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: lightPink, width: 2.5)
            : BorderSide(color: Colors.grey[700]!),
      ),
      color: isSelected ? lightPink.withAlpha(100) : Colors.grey[900],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Transform.scale(
                scale: 0.9,
                child: Radio<String>(
                  // ignore: deprecated_member_use
                  value: prompt,
                  // ignore: deprecated_member_use
                  groupValue: state.llmConfigs.selectedPrompt,
                  // ignore: deprecated_member_use
                  onChanged: (_) => onTap(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.comfortable,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prompt,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
          color: Colors.white,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: const EdgeInsets.all(7),
          tooltip: 'Edit',
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey[700]?.withAlpha(100),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
          color: Colors.red[300],
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: const EdgeInsets.all(7),
          tooltip: 'Delete',
          style: IconButton.styleFrom(
            backgroundColor: Colors.red[700]?.withAlpha(50),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderChip(String providerType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(80),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        providerType,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[700]?.withAlpha(100),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: Colors.grey[300]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[300],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

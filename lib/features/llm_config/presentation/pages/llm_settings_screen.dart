import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/radio_group.dart';
import '../../data/models/llm_config.dart';
import '../../data/models/llm_provider_type.dart';
import '../../data/models/structured_batch_overrides.dart';
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
      backgroundColor: darkGrey,
      appBar: AppBar(
        title: const Text('Vision Model Settings'),
        centerTitle: true,
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
        builder: (BuildContext context, LlmConfigsState state) {
          return SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      // Responsive breakpoint: collapse to single column on narrow screens
                      final bool useSingleColumn = constraints.maxWidth < 1024;

                      if (useSingleColumn) {
                        // Single column layout for narrow screens
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
                              flex: 5,
                              child: state.llmConfigs.configs.isEmpty
                                  ? _buildEmptyState(
                                      "No models configured yet.",
                                    )
                                  : _buildModelsList(state),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: lightGrey.withValues(alpha: 0.3),
                            ),
                            _buildSectionHeader(
                              context,
                              title: "Prompts",
                              icon: Icons.chat_bubble_outline,
                              onAdd: () => _showPromptDialog(),
                              count: state.llmConfigs.prompts.length,
                            ),
                            Expanded(
                              flex: 4,
                              child: state.llmConfigs.prompts.isEmpty
                                  ? _buildEmptyState("No prompts added yet.")
                                  : _buildPromptsList(state),
                            ),
                          ],
                        );
                      }

                      // Side-by-side layout (45/55 split)
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Models panel (45%)
                          Expanded(
                            flex: 45,
                            child: Column(
                              children: <Widget>[
                                _buildSectionHeader(
                                  context,
                                  title: "Vision Models",
                                  icon: Icons.settings_input_component,
                                  onAdd: () => _showConfigDialog(),
                                  count: state.llmConfigs.configs.length,
                                ),
                                Expanded(
                                  child: state.llmConfigs.configs.isEmpty
                                      ? _buildEmptyState(
                                          "No models configured yet.",
                                        )
                                      : _buildModelsList(state),
                                ),
                              ],
                            ),
                          ),
                          // Vertical divider
                          Container(
                            width: 1,
                            color: lightGrey.withValues(alpha: 0.3),
                          ),
                          // Prompts panel (55%)
                          Expanded(
                            flex: 55,
                            child: Column(
                              children: <Widget>[
                                _buildSectionHeader(
                                  context,
                                  title: "Prompts",
                                  icon: Icons.chat_bubble_outline,
                                  onAdd: () => _showPromptDialog(),
                                  count: state.llmConfigs.prompts.length,
                                ),
                                Expanded(
                                  child: state.llmConfigs.prompts.isEmpty
                                      ? _buildEmptyState(
                                          "No prompts added yet.",
                                        )
                                      : _buildPromptsList(state),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _buildIdeogramSection(state),
                _buildStructuredOverridesSection(state),
                _buildDebugSection(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIdeogramSection(LlmConfigsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: lightGrey.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(color: lightGrey.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.data_object, color: Colors.teal[300], size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ideogram JSON Caption',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Uses VLM + SAM3 for structured bounding box output',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: state.llmConfigs.ideogramJsonEnabled,
            onChanged: (bool value) {
              context.read<LlmConfigsCubit>().setIdeogramJsonEnabled(value);
            },
            activeThumbColor: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildDebugSection(LlmConfigsState state) {
    final bool jsonEnabled = state.llmConfigs.ideogramJsonEnabled;
    return Opacity(
      opacity: jsonEnabled ? 1.0 : 0.4,
      child: AbsorbPointer(
        absorbing: !jsonEnabled,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: lightGrey.withValues(alpha: 0.05),
            border: Border(
              top: BorderSide(color: lightGrey.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.bug_report, color: Colors.amber[300], size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Debug Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Save prompt, raw VLM response and bbox overlay image alongside each image',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.llmConfigs.debugMode,
                onChanged: (bool value) {
                  context.read<LlmConfigsCubit>().setDebugMode(value);
                },
                activeThumbColor: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStructuredOverridesSection(LlmConfigsState state) {
    final StructuredBatchOverrides overrides =
        state.llmConfigs.structuredBatchOverrides;
    final bool jsonEnabled = state.llmConfigs.ideogramJsonEnabled;
    return Opacity(
      opacity: jsonEnabled ? 1.0 : 0.4,
      child: AbsorbPointer(
        absorbing: !jsonEnabled,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: lightGrey.withValues(alpha: 0.05),
            border: Border(
              top: BorderSide(color: lightGrey.withValues(alpha: 0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header row with master toggle
              Row(
                children: <Widget>[
                  Icon(Icons.tune, color: Colors.teal[300], size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Structured Batch Overrides',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Override VLM fields for all images in a batch',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: overrides.enabled,
                    onChanged: (bool value) {
                      context
                          .read<LlmConfigsCubit>()
                          .updateStructuredBatchOverrides(
                            overrides.copyWith(enabled: value),
                          );
                    },
                    activeThumbColor: Colors.teal,
                  ),
                ],
              ),
              // Expandable content
              if (overrides.enabled) ...<Widget>[
                const SizedBox(height: 16),
                // Style — Photo or Art Style (mutually exclusive), includes medium
                _buildOverrideRow(
                  label: 'Style',
                  enabled: overrides.styleMode != null,
                  onToggle: (bool v) {
                    context
                        .read<LlmConfigsCubit>()
                        .updateStructuredBatchOverrides(
                          overrides.copyWith(
                            styleMode: v ? 'photo' : null,
                            clearStyleMode: !v,
                            clearStyleDetail: !v,
                            overrideMedium: v,
                            medium: v ? 'photograph' : null,
                            clearMedium: !v,
                          ),
                        );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          ChoiceChip(
                            label: const Text(
                              'Photo',
                              style: TextStyle(fontSize: 12),
                            ),
                            selected: overrides.styleMode == 'photo',
                            onSelected: overrides.styleMode != null
                                ? (bool v) {
                                    context
                                        .read<LlmConfigsCubit>()
                                        .updateStructuredBatchOverrides(
                                          overrides.copyWith(
                                            styleMode: v ? 'photo' : null,
                                            clearStyleMode: !v,
                                            overrideMedium: v,
                                            medium: v ? 'photograph' : null,
                                            clearMedium: !v,
                                          ),
                                        );
                                  }
                                : null,
                            selectedColor: Colors.teal[700],
                            backgroundColor: lightGrey.withValues(alpha: 0.15),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text(
                              'Art Style',
                              style: TextStyle(fontSize: 12),
                            ),
                            selected: overrides.styleMode == 'art_style',
                            onSelected: overrides.styleMode != null
                                ? (bool v) {
                                    context
                                        .read<LlmConfigsCubit>()
                                        .updateStructuredBatchOverrides(
                                          overrides.copyWith(
                                            styleMode: v ? 'art_style' : null,
                                            clearStyleMode: !v,
                                            overrideMedium: false,
                                            clearMedium: true,
                                          ),
                                        );
                                  }
                                : null,
                            selectedColor: Colors.teal[700],
                            backgroundColor: lightGrey.withValues(alpha: 0.15),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Medium field (only for Art Style — Photo auto-sets to "photograph")
                      if (overrides.styleMode == 'art_style')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text(
                                'Medium',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildOverrideTextField(
                                hint:
                                    'e.g. illustration, painting, graphic_design, 3d_render...',
                                value: overrides.medium,
                                onChanged: (String v) {
                                  context
                                      .read<LlmConfigsCubit>()
                                      .updateStructuredBatchOverrides(
                                        overrides.copyWith(
                                          medium: v.isEmpty ? null : v,
                                          clearMedium: v.isEmpty,
                                          overrideMedium: v.isNotEmpty,
                                        ),
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                      // Style detail text field
                      _buildOverrideTextField(
                        hint: overrides.styleMode == 'photo'
                            ? 'Camera, lens, depth-of-field details'
                            : 'Art style description',
                        value: overrides.styleDetail,
                        onChanged: (String v) {
                          context
                              .read<LlmConfigsCubit>()
                              .updateStructuredBatchOverrides(
                                overrides.copyWith(
                                  styleDetail: v.isEmpty ? null : v,
                                  clearStyleDetail: v.isEmpty,
                                ),
                              );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Aesthetics
                _buildOverrideRow(
                  label: 'Aesthetics',
                  enabled: overrides.overrideAesthetics,
                  onToggle: (bool v) {
                    context
                        .read<LlmConfigsCubit>()
                        .updateStructuredBatchOverrides(
                          overrides.copyWith(overrideAesthetics: v),
                        );
                  },
                  child: _buildOverrideTextField(
                    hint: '3 adjectives describing visual feel',
                    value: overrides.aesthetics,
                    onChanged: (String v) {
                      context
                          .read<LlmConfigsCubit>()
                          .updateStructuredBatchOverrides(
                            overrides.copyWith(
                              aesthetics: v.isEmpty ? null : v,
                              clearAesthetics: v.isEmpty,
                            ),
                          );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Lighting
                _buildOverrideRow(
                  label: 'Lighting',
                  enabled: overrides.overrideLighting,
                  onToggle: (bool v) {
                    context
                        .read<LlmConfigsCubit>()
                        .updateStructuredBatchOverrides(
                          overrides.copyWith(overrideLighting: v),
                        );
                  },
                  child: _buildOverrideTextField(
                    hint: 'Lighting description',
                    value: overrides.lighting,
                    onChanged: (String v) {
                      context
                          .read<LlmConfigsCubit>()
                          .updateStructuredBatchOverrides(
                            overrides.copyWith(
                              lighting: v.isEmpty ? null : v,
                              clearLighting: v.isEmpty,
                            ),
                          );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Background
                _buildOverrideRow(
                  label: 'Background',
                  enabled: overrides.overrideBackground,
                  onToggle: (bool v) {
                    context
                        .read<LlmConfigsCubit>()
                        .updateStructuredBatchOverrides(
                          overrides.copyWith(overrideBackground: v),
                        );
                  },
                  child: _buildOverrideTextField(
                    hint: 'Background description',
                    value: overrides.background,
                    maxLines: 3,
                    onChanged: (String v) {
                      context
                          .read<LlmConfigsCubit>()
                          .updateStructuredBatchOverrides(
                            overrides.copyWith(
                              background: v.isEmpty ? null : v,
                              clearBackground: v.isEmpty,
                            ),
                          );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverrideRow({
    required String label,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 140,
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[300],
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                width: 32,
                child: Checkbox(
                  value: enabled,
                  onChanged: (bool? v) {
                    if (v != null) onToggle(v);
                  },
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeColor: Colors.teal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildOverrideTextField({
    String? hint,
    String? value,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: TextEditingController(text: value ?? '')
        ..selection = TextSelection.collapsed(offset: (value ?? '').length),
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      onChanged: onChanged,
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
            onDuplicate: () =>
                context.read<LlmConfigsCubit>().duplicateLlmConfig(config.id),
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
            onDuplicate: () =>
                context.read<LlmConfigsCubit>().duplicatePrompt(prompt),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      color: darkGrey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontSize: 17,
                  letterSpacing: -0.2,
                ),
              ),
              if (count > 0) ...<Widget>[
                const SizedBox(width: 12),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[500],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ],
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 20),
            tooltip: "Add New",
            color: Colors.white70,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: lightGrey.withValues(alpha: 0.2),
              hoverColor: lightGrey.withValues(alpha: 0.3),
            ),
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
          Icon(Icons.inbox, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.2,
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
    required VoidCallback onDuplicate,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? lightPink.withValues(alpha: 0.5)
                : lightGrey.withValues(alpha: 0.2),
          ),
        ),
        color: isSelected
            ? lightPink.withValues(alpha: 0.12)
            : lightGrey.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: lightGrey.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? lightPink : Colors.grey[700]!,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: lightPink,
                            ),
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        config.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.model,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          _buildMinimalChip(config.providerType.name),
                          if (config.providerType == LlmProviderType.remote &&
                              config.url != null) ...<Widget>[
                            const SizedBox(width: 6),
                            _buildMinimalChip(config.url!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _buildHoverActionButtons(onEdit, onDelete, onDuplicate),
              ],
            ),
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
    required VoidCallback onDuplicate,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? lightPink.withValues(alpha: 0.5)
                : lightGrey.withValues(alpha: 0.2),
          ),
        ),
        color: isSelected
            ? lightPink.withValues(alpha: 0.12)
            : lightGrey.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: lightGrey.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 14, top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? lightPink : Colors.grey[700]!,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: lightPink,
                            ),
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    prompt,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[100],
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                _buildHoverActionButtons(onEdit, onDelete, onDuplicate),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoverActionButtons(
    VoidCallback onEdit,
    VoidCallback onDelete,
    VoidCallback onDuplicate,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: onDuplicate,
            color: Colors.grey[400],
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
            tooltip: 'Duplicate',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              hoverColor: lightGrey.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            color: Colors.grey[400],
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
            tooltip: 'Edit',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              hoverColor: lightGrey.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
            color: Colors.grey[500],
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
            tooltip: 'Delete',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              hoverColor: lightGrey.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: lightGrey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: Colors.grey[500],
          letterSpacing: -0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

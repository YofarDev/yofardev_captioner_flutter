import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/llm_config.dart';
import '../../data/models/llm_provider_type.dart';
import '../../logic/llm_configs_cubit.dart';

/// Add / edit a vision model configuration.
///
/// Behaviour preserved verbatim from the original inline dialog; only the
/// visual treatment is new (pink focus borders, terminal inputs).
class LlmConfigDialog extends StatefulWidget {
  final LlmConfig? config;
  final VoidCallback? onAdded;

  const LlmConfigDialog({super.key, this.config, this.onAdded});

  /// Convenience entry point matching the legacy call sites.
  static Future<void> show(
    BuildContext context, {
    LlmConfig? config,
    VoidCallback? onAdded,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => LlmConfigDialog(config: config, onAdded: onAdded),
    );
  }

  @override
  State<LlmConfigDialog> createState() => _LlmConfigDialogState();
}

class _LlmConfigDialogState extends State<LlmConfigDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _delayController;
  late final TextEditingController _mlxPathController;

  late LlmProviderType _selectedProviderType;

  @override
  void initState() {
    super.initState();
    final LlmConfig? config = widget.config;
    _nameController = TextEditingController(text: config?.name);
    _urlController = TextEditingController(text: config?.url);
    _modelController = TextEditingController(text: config?.model);
    _apiKeyController = TextEditingController(text: config?.apiKey);
    _delayController = TextEditingController(
      text: config?.delay.toString() ?? '0',
    );
    _mlxPathController = TextEditingController(text: config?.mlxPath);

    _selectedProviderType = config?.providerType ?? LlmProviderType.remote;

    // Pre-fill model for macOS users when adding a new local config
    if (widget.config == null &&
        Platform.isMacOS &&
        _selectedProviderType == LlmProviderType.localMlx) {
      _modelController.text = 'mlx-community/Qwen3-VL-4B-Instruct-5bit';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _delayController.dispose();
    _mlxPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.config != null;

    return AlertDialog(
      backgroundColor: panelRaised,
      title: Row(
        children: <Widget>[
          Icon(
            isEditing ? Icons.edit_note : Icons.add_circle_outline,
            color: lightPink,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            isEditing ? 'Edit Configuration' : 'Add Configuration',
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: hairline),
      ),
      content: StatefulBuilder(
        builder:
            (BuildContext context, void Function(void Function()) setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 4),
                    DropdownButtonFormField<LlmProviderType>(
                      initialValue: _selectedProviderType,
                      dropdownColor: panelRaised,
                      onChanged: (LlmProviderType? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedProviderType = newValue;
                            if (widget.config == null &&
                                Platform.isMacOS &&
                                _selectedProviderType ==
                                    LlmProviderType.localMlx) {
                              _modelController.text =
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
                      decoration: _fieldDecoration('Provider Type'),
                    ),
                    const SizedBox(height: 14),
                    if (_selectedProviderType == LlmProviderType.remote)
                      _buildField(
                        _nameController,
                        'Name',
                        autofocus: !isEditing,
                      ),
                    if (_selectedProviderType ==
                        LlmProviderType.remote) ...<Widget>[
                      _buildField(_urlController, 'URL'),
                      _buildField(_apiKeyController, 'API Key', obscure: true),
                    ],
                    _buildField(
                      _modelController,
                      'Model',
                      autofocus:
                          _selectedProviderType == LlmProviderType.localMlx &&
                          !isEditing,
                    ),
                    if (_selectedProviderType == LlmProviderType.localMlx)
                      _buildField(
                        _mlxPathController,
                        'Executable Path (optional)',
                      ),
                    if (_selectedProviderType == LlmProviderType.remote)
                      _buildField(
                        _delayController,
                        'Delay (ms)',
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
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: lightPink,
            foregroundColor: darkGrey,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final bool isEditing = widget.config != null;
    final bool isLocal = _selectedProviderType == LlmProviderType.localMlx;
    final LlmConfig newConfig = LlmConfig(
      id: widget.config?.id,
      name: isLocal
          ? _modelController.text.split('/').last
          : _nameController.text,
      url: isLocal ? null : _urlController.text,
      model: _modelController.text,
      apiKey: isLocal ? null : _apiKeyController.text,
      delay: isLocal ? 0 : int.tryParse(_delayController.text) ?? 0,
      providerType: _selectedProviderType,
      mlxPath: isLocal ? _mlxPathController.text : null,
    );
    if (isEditing) {
      context.read<LlmConfigsCubit>().updateLlmConfig(newConfig);
    } else {
      context.read<LlmConfigsCubit>().addLlmConfig(newConfig);
      widget.onAdded?.call();
    }
    Navigator.of(context).pop();
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    TextInputType inputType = TextInputType.text,
    bool autofocus = false,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        autofocus: autofocus,
        obscureText: obscure,
        style: const TextStyle(color: textPrimary, fontSize: 14),
        decoration: _fieldDecoration(label),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: lightPink, fontSize: 13),
      filled: true,
      fillColor: panelDark,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: BorderSide(color: lightPink.withValues(alpha: 0.7)),
      ),
    );
  }
}

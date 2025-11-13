import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/llm_config/llm_configs_cubit.dart';
import '../../models/llm_config.dart';
import '../../res/app_colors.dart';

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
      text: config?.delay.toString(),
    );
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Config' : 'Add Config'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                TextField(
                  controller: apiKeyController,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                TextField(
                  controller: delayController,
                  decoration: const InputDecoration(labelText: 'Delay (ms)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final LlmConfig newConfig = LlmConfig(
                  id: config?.id,
                  name: nameController.text,
                  url: urlController.text,
                  model: modelController.text,
                  apiKey: apiKeyController.text,
                  delay: int.tryParse(delayController.text) ?? 0,
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

  Future<void> _showPromptDialog(String currentPrompt) async {
    final TextEditingController promptController = TextEditingController(
      text: currentPrompt,
    );
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Prompt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    labelText: 'Prompt',
                    hintText: 'Enter your prompt text here',
                  ),
                  maxLines: 5,
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
            ElevatedButton(
              onPressed: () {
                final String newPrompt = promptController.text;
                context.read<LlmConfigsCubit>().updatePrompt(newPrompt);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,
      floatingActionButton: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lightPink.withAlpha(50),
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        onPressed: () => _showConfigDialog(),
      ),
      appBar: AppBar(
        title: const Text('LLM Settings'),
        backgroundColor: darkGrey,
      ),
      body: BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
        builder: (BuildContext context, LlmConfigsState state) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text("Prompt:"),
                ListTile(
                  title: state.llmConfigs.prompt.isEmpty
                      ? const Text("No prompt")
                      : Text(state.llmConfigs.prompt),
                  onTap: () => _showPromptDialog(state.llmConfigs.prompt),
                ),
                const SizedBox(height: 16),
                const Text("Models:"),
                if (state.llmConfigs.configs.isEmpty)
                  const Center(child: Text("No models")),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.llmConfigs.configs.length,
                    itemBuilder: (BuildContext context, int index) {
                      final LlmConfig config = state.llmConfigs.configs[index];
                      return ListTile(
                        title: Text(config.name),
                        subtitle: Text(config.model),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showConfigDialog(config),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                context.read<LlmConfigsCubit>().deleteLlmConfig(
                                  config.id,
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

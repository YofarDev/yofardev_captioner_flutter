import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/llm_configs_cubit.dart';
import '../../data/models/llm_config.dart';

class LlmConfigWidget extends StatelessWidget {
  const LlmConfigWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
      builder: (BuildContext context, LlmConfigsState state) {
        return Row(
          children: <Widget>[
            const Text('Model: '),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: state.llmConfigs.selectedConfigId,
              isDense: true,
              style: const TextStyle(fontSize: 12),

              hint: const Text(
                "Select Model",
                style: TextStyle(fontSize: 12, height: 1),
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  context.read<LlmConfigsCubit>().selectLlmConfig(newValue);
                }
              },
              items: state.llmConfigs.configs.map<DropdownMenuItem<String>>((
                LlmConfig config,
              ) {
                return DropdownMenuItem<String>(
                  value: config.id,
                  child: Text(config.name),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

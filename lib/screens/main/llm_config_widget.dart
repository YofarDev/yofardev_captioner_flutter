import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/images_cubit.dart';
import '../../models/llm_config.dart';

class LlmConfigWidget extends StatelessWidget {
  const LlmConfigWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImagesCubit, ImagesState>(
      builder: (BuildContext context, ImagesState state) {
        return Row(
          children: <Widget>[
            const Text('Model: '),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: DropdownButton<String>(
                value: state.llmConfigs.selectedConfigId,
                isDense: true,
                hint: const Text(
                  "Select Model",
                  style: TextStyle(fontSize: 12),
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    context.read<ImagesCubit>().selectLlmConfig(newValue);
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
            ),
          ],
        );
      },
    );
  }
}

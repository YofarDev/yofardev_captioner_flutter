import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/llm_config.dart';
import '../../logic/llm_configs_cubit.dart';

class LlmConfigWidget extends StatelessWidget {
  const LlmConfigWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
      builder: (BuildContext context, LlmConfigsState state) {
        final List<DropdownMenuItem<String>> items =
            _buildGroupedItems(state.llmConfigs.configs);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: DropdownButton<String>(
                value: state.llmConfigs.selectedConfigId,
                isDense: true,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: Colors.grey[850],
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                underline: const SizedBox.shrink(),
                hint: const Text(
                  "Select Model",
                  style: TextStyle(fontSize: 13, height: 1),
                ),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    context.read<LlmConfigsCubit>().selectLlmConfig(newValue);
                  }
                },
                items: items,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Sorts configs by provider (URL host) then by name, and inserts
  /// non-selectable group headers between groups.
  static List<DropdownMenuItem<String>> _buildGroupedItems(
    List<LlmConfig> configs,
  ) {
    final List<LlmConfig> sorted = _sortedGrouped(configs);

    final List<DropdownMenuItem<String>> items = <DropdownMenuItem<String>>[];
    String? currentGroup;
    for (final LlmConfig config in sorted) {
      final String label = config.providerLabel;
      if (label != currentGroup) {
        currentGroup = label;
        items.add(
          DropdownMenuItem<String>(
            value: '__group__${config.id}',
            enabled: false,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Colors.pinkAccent.withValues(alpha: 0.85),
              ),
            ),
          ),
        );
      }
      items.add(
        DropdownMenuItem<String>(
          value: config.id,
          child: Text(config.name),
        ),
      );
    }
    return items;
  }
}

/// Sorts configs by provider label (case-insensitive) then by name
/// (case-insensitive).
List<LlmConfig> _sortedGrouped(List<LlmConfig> configs) {
  return List<LlmConfig>.of(configs)
    ..sort((LlmConfig a, LlmConfig b) {
      final int groupCmp = a.providerLabel
          .toLowerCase()
          .compareTo(b.providerLabel.toLowerCase());
      if (groupCmp != 0) return groupCmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/radio_group.dart';
import '../../data/models/llm_config.dart';
import '../../data/models/llm_provider_type.dart';
import '../../logic/llm_configs_cubit.dart';
import 'llm_config_dialog.dart';
import 'prompt_dialog.dart';
import 'settings_section_header.dart';

/// Tab body: vision models (left) + prompts (right).
///
/// Owns the full body height now that the structured pipeline moved to its own
/// tab — no footer competes for vertical space.
class ModelsPromptsPanel extends StatefulWidget {
  const ModelsPromptsPanel({super.key});

  @override
  State<ModelsPromptsPanel> createState() => _ModelsPromptsPanelState();
}

class _ModelsPromptsPanelState extends State<ModelsPromptsPanel> {
  final ScrollController _modelsScrollController = ScrollController();
  final ScrollController _promptsScrollController = ScrollController();

  @override
  void dispose() {
    _modelsScrollController.dispose();
    _promptsScrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LlmConfigsCubit, LlmConfigsState>(
      builder: (BuildContext context, LlmConfigsState state) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool useSingleColumn = constraints.maxWidth < 1024;

            if (useSingleColumn) {
              return Column(
                children: <Widget>[
                  SettingsSectionHeader(
                    index: '01',
                    title: 'Vision Models',
                    count: state.llmConfigs.configs.length,
                    onAdd: () => LlmConfigDialog.show(
                      context,
                      onAdded: () => _scrollToBottom(_modelsScrollController),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: state.llmConfigs.configs.isEmpty
                        ? const _EmptyState('No models configured yet.')
                        : _buildModelsList(state),
                  ),
                  Container(height: 1, color: hairline),
                  SettingsSectionHeader(
                    index: '02',
                    title: 'Prompts',
                    count: state.llmConfigs.prompts.length,
                    onAdd: () => PromptDialog.show(
                      context,
                      onAdded: () => _scrollToBottom(_promptsScrollController),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: state.llmConfigs.prompts.isEmpty
                        ? const _EmptyState('No prompts added yet.')
                        : _buildPromptsList(state),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  flex: 45,
                  child: Column(
                    children: <Widget>[
                      SettingsSectionHeader(
                        index: '01',
                        title: 'Vision Models',
                        count: state.llmConfigs.configs.length,
                        onAdd: () => LlmConfigDialog.show(
                          context,
                          onAdded: () =>
                              _scrollToBottom(_modelsScrollController),
                        ),
                      ),
                      Expanded(
                        child: state.llmConfigs.configs.isEmpty
                            ? const _EmptyState('No models configured yet.')
                            : _buildModelsList(state),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, color: hairline),
                Expanded(
                  flex: 55,
                  child: Column(
                    children: <Widget>[
                      SettingsSectionHeader(
                        index: '02',
                        title: 'Prompts',
                        count: state.llmConfigs.prompts.length,
                        onAdd: () => PromptDialog.show(
                          context,
                          onAdded: () =>
                              _scrollToBottom(_promptsScrollController),
                        ),
                      ),
                      Expanded(
                        child: state.llmConfigs.prompts.isEmpty
                            ? const _EmptyState('No prompts added yet.')
                            : _buildPromptsList(state),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
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
        separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final LlmConfig config = state.llmConfigs.configs[index];
          final bool isSelected =
              config.id == state.llmConfigs.selectedConfigId;
          return _ConfigCard(
            config: config,
            isSelected: isSelected,
            onTap: () =>
                context.read<LlmConfigsCubit>().selectLlmConfig(config.id),
            onEdit: () => LlmConfigDialog.show(context, config: config),
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
        separatorBuilder: (BuildContext _, int _) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final String prompt = state.llmConfigs.prompts[index];
          final bool isSelected = prompt == state.llmConfigs.selectedPrompt;
          return _PromptCard(
            prompt: prompt,
            index: index,
            isSelected: isSelected,
            onTap: () => context.read<LlmConfigsCubit>().selectPrompt(prompt),
            onEdit: () =>
                PromptDialog.show(context, oldPrompt: prompt, index: index),
            onDelete: () =>
                context.read<LlmConfigsCubit>().deletePrompt(prompt),
            onDuplicate: () =>
                context.read<LlmConfigsCubit>().duplicatePrompt(prompt),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.inbox_outlined, size: 44, color: textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: textMuted,
              fontSize: 13,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigCard extends StatefulWidget {
  final LlmConfig config;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _ConfigCard({
    required this.config,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  State<_ConfigCard> createState() => _ConfigCardState();
}

class _ConfigCardState extends State<_ConfigCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final LlmConfig config = widget.config;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? pinkSurface
                : _hovered
                ? panelRaised
                : panelDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? lightPink.withValues(alpha: 0.6)
                  : hairline,
            ),
          ),
          child: Row(
            children: <Widget>[
              _SelectionDot(isSelected: widget.isSelected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      config.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      config.model,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _Chip(config.providerType.name),
                        if (config.providerType == LlmProviderType.remote &&
                            config.url != null)
                          _Chip(config.url!),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 130),
                opacity: _hovered || widget.isSelected ? 1 : 0.35,
                child: _HoverActions(
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                  onDuplicate: widget.onDuplicate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptCard extends StatefulWidget {
  final String prompt;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _PromptCard({
    required this.prompt,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  bool _hovered = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? pinkSurface
                : _hovered
                ? panelRaised
                : panelDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? lightPink.withValues(alpha: 0.6)
                  : hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _SelectionDot(isSelected: widget.isSelected),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.prompt,
                  maxLines: _expanded ? null : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: textPrimary,
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 130),
                opacity: _hovered || widget.isSelected ? 1 : 0.35,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _IconBtn(
                      icon: _expanded ? Icons.expand_less : Icons.expand_more,
                      tooltip: _expanded ? 'Collapse' : 'Expand',
                      onTap: () => setState(() => _expanded = !_expanded),
                    ),
                    _HoverActions(
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                      onDuplicate: widget.onDuplicate,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  final bool isSelected;
  const _SelectionDot({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? lightPink : textMuted,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: isSelected
          ? Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: lightPink,
              ),
            )
          : null,
    );
  }
}

class _HoverActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _HoverActions({
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _IconBtn(
          icon: Icons.copy_outlined,
          tooltip: 'Duplicate',
          onTap: onDuplicate,
        ),
        _IconBtn(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: onEdit),
        _IconBtn(
          icon: Icons.delete_outline,
          tooltip: 'Delete',
          onTap: onDelete,
          destructive: true,
        ),
      ],
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool destructive;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: _hovered
                  ? (widget.destructive
                        ? destructive.withValues(alpha: 0.16)
                        : lightPink.withValues(alpha: 0.14))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 17,
              color: _hovered
                  ? (widget.destructive ? destructive.withValues(alpha: 0.7) : lightPink)
                  : textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: hairline,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          color: textSecondary,
          letterSpacing: 0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

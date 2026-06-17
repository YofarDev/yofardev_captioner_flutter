import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../widgets/models_prompts_panel.dart';
import '../widgets/structured_panel.dart';

/// Vision model settings — reworked into a two-tab shell so the structured
/// pipeline no longer competes for vertical space with the model/prompt lists.
class LlmSettingsScreen extends StatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  State<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends State<LlmSettingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGrey,
      appBar: AppBar(
        title: const Text(
          'VISION MODEL SETTINGS',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        centerTitle: true,
        backgroundColor: darkGrey,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _SegmentedTabs(
            current: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const <Widget>[ModelsPromptsPanel(), StructuredPanel()],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({required this.current, required this.onChanged});

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(index: '01', label: 'Models & Prompts'),
    _TabSpec(index: '03', label: 'Structured'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: panelDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hairline),
        ),
        child: Row(
          children: _tabs
              .map(
                (_TabSpec t) => Expanded(
                  child: _SegmentedTab(
                    spec: t,
                    selected: current == _tabs.indexOf(t),
                    onTap: () => onChanged(_tabs.indexOf(t)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _TabSpec {
  final String index;
  final String label;
  const _TabSpec({required this.index, required this.label});
}

class _SegmentedTab extends StatefulWidget {
  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentedTab({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SegmentedTab> createState() => _SegmentedTabState();
}

class _SegmentedTabState extends State<_SegmentedTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? lightPink.withValues(alpha: 0.16)
                : (_hovered
                      ? lightPink.withValues(alpha: 0.06)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: active
                  ? lightPink.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.spec.index,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: active
                      ? lightPink
                      : (_hovered
                            ? lightPink.withValues(alpha: 0.7)
                            : textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.spec.label,
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: active ? textPrimary : textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cache_service.dart';
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
      body: Column(
        children: <Widget>[
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const <Widget>[
                ModelsPromptsPanel(),
                StructuredPanel(),
              ],
            ),
          ),
          const _MaxImageSizeBar(),
        ],
      ),
    );
  }
}

/// Persistent footer controlling the longest-edge size images are downscaled
/// to before being sent to the VLM. Stored in [CacheService]; read live by
/// [ImageResizer] at caption time, so changes apply to the next caption run.
class _MaxImageSizeBar extends StatefulWidget {
  const _MaxImageSizeBar();

  @override
  State<_MaxImageSizeBar> createState() => _MaxImageSizeBarState();
}

class _MaxImageSizeBarState extends State<_MaxImageSizeBar> {
  final TextEditingController _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    CacheService.loadMaxImageDimension().then((int value) {
      if (!mounted) return;
      _controller.text = value.toString();
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _persist() {
    final int? parsed = int.tryParse(_controller.text.trim());
    if (parsed != null && parsed > 0) {
      CacheService.saveMaxImageDimension(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: darkGrey,
        border: Border(top: BorderSide(color: hairline)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.photo_size_select_large_outlined,
            size: 18,
            color: lightPink,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                Text(
                  'MAX IMAGE SIZE',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Images are downscaled to this longest-edge size before being sent to the VLM.',
                  style: TextStyle(color: textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 96,
            child: TextField(
              controller: _controller,
              enabled: _loaded,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              onChanged: (_) => _persist(),
              onSubmitted: (_) => _persist(),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                suffixText: 'px',
                suffixStyle: const TextStyle(color: textSecondary, fontSize: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: const BorderSide(color: hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: BorderSide(
                    color: lightPink.withValues(alpha: 0.6),
                  ),
                ),
              ),
              style: const TextStyle(color: textPrimary, fontSize: 13),
            ),
          ),
        ],
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

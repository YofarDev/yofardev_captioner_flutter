import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Carries the display data for a single tag chip.
class _ChipData {
  const _ChipData(this.label, this.active);

  final String label;
  final bool active;
}

/// Manages an [OverlayEntry] that displays toggleable tag-filter chips below
/// a search field via a [LayerLink]/[CompositedTransformFollower] pair.
///
/// Mirrors [SearchAutocompleteOverlay]: an [OverlayEntry] is not unmounted by
/// ancestor rebuilds, and chips use [GestureDetector] (not [InkWell]) so a tap
/// never steals focus from the search field — the field keeps focus and the
/// overlay stays open for further interaction.
class TagFilterChipsOverlay {
  TagFilterChipsOverlay._();

  static final Map<OverlayEntry, ValueNotifier<List<_ChipData>>> _notifiers =
      <OverlayEntry, ValueNotifier<List<_ChipData>>>{};

  /// Shows a chips dropdown anchored to [link]. Returns the [OverlayEntry] so
  /// callers can [update] / [remove] it later.
  static OverlayEntry show({
    required BuildContext context,
    required LayerLink link,
    required List<({String label, bool active})> chips,
    required ValueChanged<String> onToggle,
    required VoidCallback onDismiss,
  }) {
    final ValueNotifier<List<_ChipData>> notifier =
        ValueNotifier<List<_ChipData>>(
      chips.map((({String label, bool active}) c) => _ChipData(c.label, c.active)).toList(),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) => _ChipsDropdown(
        link: link,
        notifier: notifier,
        onToggle: onToggle,
        onDismiss: onDismiss,
      ),
    );

    _notifiers[entry] = notifier;
    Overlay.of(context).insert(entry);
    return entry;
  }

  /// Replaces the chips shown in [entry] with [chips] without re-inserting.
  static void update(
    OverlayEntry entry,
    List<({String label, bool active})> chips,
  ) {
    final ValueNotifier<List<_ChipData>>? notifier = _notifiers[entry];
    if (notifier != null) {
      notifier.value =
          chips.map((({String label, bool active}) c) => _ChipData(c.label, c.active)).toList();
    }
  }

  /// Removes the overlay entry. Safe to call multiple times.
  static void remove(OverlayEntry entry) {
    if (!_notifiers.containsKey(entry)) return;
    _notifiers.remove(entry);
    entry.remove();
  }
}

class _ChipsDropdown extends StatefulWidget {
  const _ChipsDropdown({
    required this.link,
    required this.notifier,
    required this.onToggle,
    required this.onDismiss,
  });

  final LayerLink link;
  final ValueNotifier<List<_ChipData>> notifier;
  final ValueChanged<String> onToggle;
  final VoidCallback onDismiss;

  @override
  State<_ChipsDropdown> createState() => _ChipsDropdownState();
}

class _ChipsDropdownState extends State<_ChipsDropdown> {
  List<_ChipData> _chips = const <_ChipData>[];
  String? _hoveredLabel;

  @override
  void initState() {
    super.initState();
    _chips = widget.notifier.value;
    widget.notifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _chips = widget.notifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: widget.link,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, 4),
      // UnconstrainedBox detaches the panel from the overlay's full-screen
      // constraints so it shrinks to its own content; ConstrainedBox caps it.
      // Without this the Column expands to the overlay height (fills the view).
      child: UnconstrainedBox(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 240),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: darkGrey,
            child: Container(
              key: const Key('tagFilterChipsOverlay'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      'FILTER BY TAG',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 10,
                        color: lightPink,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _chips.map(_buildChip).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(_ChipData chip) {
    final bool isHovered = _hoveredLabel == chip.label;
    final Color background = chip.active
        ? pinkSurface
        : (isHovered ? Colors.white.withValues(alpha: 0.06) : panelRaised);
    final Color border = chip.active ? accentPink : hairline;
    final Color textColor = chip.active ? lightPink : textPrimary;
    final Color hashColor = chip.active
        ? accentPink
        : textMuted.withValues(alpha: 0.7);
    final FontWeight weight = chip.active ? FontWeight.w600 : FontWeight.w400;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (PointerEnterEvent _) {
        setState(() {
          _hoveredLabel = chip.label;
        });
      },
      onExit: (PointerExitEvent _) {
        setState(() {
          _hoveredLabel = null;
        });
      },
      child: GestureDetector(
        onTap: () => widget.onToggle(chip.label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: border, width: chip.active ? 0.75 : 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '#',
                style: TextStyle(
                  color: hashColor,
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: weight,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                chip.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontFamily: 'Inter',
                  fontWeight: weight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

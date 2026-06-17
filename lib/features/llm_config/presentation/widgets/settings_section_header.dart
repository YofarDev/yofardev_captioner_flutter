import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Section header for the settings panels.
///
/// Terminal-styled: monospaced index prefix, Orbitron label, pink count badge,
/// hairline divider underneath. One visual language for every panel.
class SettingsSectionHeader extends StatelessWidget {
  final String index;
  final String title;
  final int count;
  final VoidCallback onAdd;
  final String addTooltip;

  const SettingsSectionHeader({
    super.key,
    required this.index,
    required this.title,
    required this.onAdd,
    this.count = 0,
    this.addTooltip = 'Add New',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
      decoration: const BoxDecoration(
        color: darkGrey,
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            index,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: lightPink,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              letterSpacing: 1.2,
            ),
          ),
          if (count > 0) ...<Widget>[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: lightPink.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: lightPink.withValues(alpha: 0.35)),
              ),
              child: Text(
                count.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: lightPink,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
          const Spacer(),
          _AddButton(onPressed: onAdd, tooltip: addTooltip),
        ],
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const _AddButton({required this.onPressed, required this.tooltip});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _hovered
                  ? lightPink.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _hovered ? lightPink.withValues(alpha: 0.6) : hairline,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 17,
              color: _hovered ? lightPink : textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

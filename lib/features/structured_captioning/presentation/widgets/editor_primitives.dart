import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Compact Orbitron header used to title each block of the editor panels.
///
/// Mirrors the app's terminal header language: uppercase Orbitron, pink accent,
/// hairline underline. One visual rhythm for every section of the right panel.
class EditorSectionHeader extends StatelessWidget {
  const EditorSectionHeader(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: lightPink,
              letterSpacing: 1.4,
            ),
          ),
          if (trailing != null) ...<Widget>[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Medium-weight sub-section label (e.g. "Color Palette").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
    );
  }
}

/// Small muted label for field rows (e.g. "Position", "Medium").
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: textMuted,
      ),
    );
  }
}

/// A fixed-width label paired with an editor widget, for compact forms.
class LabeledFieldRow extends StatelessWidget {
  const LabeledFieldRow({
    required this.label,
    required this.child,
    this.labelWidth = 72,
    super.key,
  });

  final String label;
  final Widget child;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: labelWidth, child: FieldLabel(label)),
        Expanded(child: child),
      ],
    );
  }
}

/// Synced text field used across the editor panels.
///
/// Owns its controller so the cursor survives parent rebuilds and re-seeds the
/// text (preserving cursor position) when the upstream value changes.
class EditorTextField extends StatefulWidget {
  const EditorTextField({
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.dense = false,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool dense;

  @override
  State<EditorTextField> createState() => _EditorTextFieldState();
}

class _EditorTextFieldState extends State<EditorTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant EditorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value &&
        widget.value != _controller.text) {
      final int sel = _controller.selection.baseOffset;
      _controller.text = widget.value;
      _controller.selection =
          TextSelection.collapsed(offset: sel.clamp(0, widget.value.length));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      enabled: widget.enabled,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: widget.dense ? 13 : 14,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: panelRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.dense ? 6 : 8),
          borderSide: BorderSide.none,
        ),
        contentPadding: widget.dense
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: widget.dense,
      ),
      onChanged: widget.onChanged,
    );
  }
}

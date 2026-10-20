import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/caption_options.dart';

/// Radio-row selector for which images a captioning run targets
/// (current / missing / all). Purely presentational — the selected
/// [CaptionOptions] lives in the parent controls state.
class CaptionModeSelector extends StatelessWidget {
  const CaptionModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.missingCount,
    required this.totalImages,
  });

  final CaptionOptions selected;
  final ValueChanged<CaptionOptions?> onChanged;
  final int missingCount;
  final int totalImages;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<CaptionOptions>(
      groupValue: selected,
      onChanged: onChanged,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              "Caption: ",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            _ModeRadioButton(
              label: 'This image',
              option: CaptionOptions.current,
              selected: selected,
              onChanged: onChanged,
            ),
            const SizedBox(width: 12),
            _ModeRadioButton(
              label: 'Missing captions ($missingCount)',
              option: CaptionOptions.missing,
              selected: selected,
              onChanged: onChanged,
            ),
            const SizedBox(width: 12),
            _ModeRadioButton(
              label: 'All ($totalImages)',
              option: CaptionOptions.all,
              selected: selected,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeRadioButton extends StatelessWidget {
  const _ModeRadioButton({
    required this.label,
    required this.option,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final CaptionOptions option;
  final CaptionOptions selected;
  final ValueChanged<CaptionOptions?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selected == option;
    return InkWell(
      onTap: () => onChanged(option),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? lightPink.withAlpha(80)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? lightPink.withAlpha(150)
                : Colors.white.withAlpha(30),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Transform.scale(
              scale: 0.8,
              child: Radio<CaptionOptions>(
                value: option,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                fillColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return lightPink;
                  }
                  return Colors.grey;
                }),
              ),
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

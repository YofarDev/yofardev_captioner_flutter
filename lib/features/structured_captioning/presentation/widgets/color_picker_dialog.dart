import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Dialog wrapper around Flutter's built-in color picker.
///
/// Returns the selected color as a hex string (e.g. "#FF0000") or null if
/// cancelled.
Future<String?> showColorPickerDialog(
  BuildContext context, {
  String? initialColor,
}) async {
  Color current = _parseHex(initialColor ?? '#FFFFFF');

  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: lightGrey,
        title: const Text(
          'Pick a color',
          style: TextStyle(color: textPrimary, fontFamily: 'Inter'),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _HsvPicker(
                  currentColor: current,
                  onColorChanged: (Color color) {
                    current = color;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: current,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _colorToHex(current),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Inter',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: <TextButton>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_colorToHex(current)),
            child: const Text('Select'),
          ),
        ],
      );
    },
  );

  return result;
}

/// Simple HSV-based color picker.
class _HsvPicker extends StatefulWidget {
  const _HsvPicker({required this.currentColor, required this.onColorChanged});

  final Color currentColor;
  final ValueChanged<Color> onColorChanged;

  @override
  State<_HsvPicker> createState() => _HsvPickerState();
}

class _HsvPickerState extends State<_HsvPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.currentColor);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Saturation/Value square
        SizedBox(
          width: 240,
          height: 180,
          child: CustomPaint(
            painter: _SVPickerPainter(
              hue: _hsv.hue,
              saturation: _hsv.saturation,
              value: _hsv.value,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Hue slider
        SizedBox(
          width: 240,
          height: 20,
          child: Slider(
            value: _hsv.hue,
            max: 360,
            activeColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
            onChanged: (double v) {
              setState(() {
                _hsv = _hsv.withHue(v);
              });
              widget.onColorChanged(_hsv.toColor());
            },
          ),
        ),
      ],
    );
  }
}

class _SVPickerPainter extends CustomPainter {
  _SVPickerPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    // White-to-hue gradient (horizontal)
    final Paint huePaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.white,
          HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), huePaint);

    // Transparent-to-black gradient (vertical)
    final Paint blackPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0x00000000), Colors.black],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), blackPaint);

    // Selector circle
    final double cx = saturation * size.width;
    final double cy = (1 - value) * size.height;
    final Paint circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), 7, circlePaint);
    final Paint fillPaint = Paint()
      ..color = HSVColor.fromAHSV(1, hue, saturation, value).toColor();
    canvas.drawCircle(Offset(cx, cy), 6, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SVPickerPainter oldDelegate) {
    return hue != oldDelegate.hue ||
        saturation != oldDelegate.saturation ||
        value != oldDelegate.value;
  }
}

Color _parseHex(String hex) {
  String cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    cleaned = 'FF$cleaned';
  }
  return Color(int.parse(cleaned, radix: 16));
}

String _colorToHex(Color color) {
  return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
}

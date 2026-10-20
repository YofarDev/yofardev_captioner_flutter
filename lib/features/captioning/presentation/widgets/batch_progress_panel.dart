import 'package:flutter/material.dart';

import '../../../../core/widgets/rive_animations.dart';

/// Danger-style interrupt control. Squared stop glyph + danger glow,
/// lifts on hover, pulses while waiting for the in-flight job to settle.
class StopButton extends StatefulWidget {
  const StopButton({
    super.key,
    required this.onTap,
    required this.isCancelling,
  });

  final VoidCallback onTap;
  final bool isCancelling;

  @override
  State<StopButton> createState() => _StopButtonState();
}

class _StopButtonState extends State<StopButton>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(covariant StopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCancelling && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isCancelling && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = !widget.isCancelling;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _hover && enabled ? 1.035 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  const Color(
                    0xFFE5484D,
                  ).withAlpha(_hover && enabled ? 255 : 232),
                  const Color(
                    0xFFB32217,
                  ).withAlpha(_hover && enabled ? 245 : 214),
                ],
              ),
              border: Border.all(
                color: Colors.white.withAlpha(_hover && enabled ? 95 : 38),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(
                    0xFFE5484D,
                  ).withAlpha(_hover && enabled ? 130 : 72),
                  blurRadius: _hover ? 22 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.isCancelling)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(enabled ? 255 : 170),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                const SizedBox(width: 9),
                Text(
                  widget.isCancelling ? 'Stopping' : 'Stop',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    fontFamily: 'Orbitron',
                  ),
                ),
                if (widget.isCancelling) ...<Widget>[
                  const SizedBox(width: 8),
                  FadeTransition(
                    opacity: _pulse,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// In-progress batch pill: processing indicator, optional step label,
/// processed/total count, and a stop control. Shown while a captioning
/// or structured-captioning run is in flight.
class BatchProgressPanel extends StatelessWidget {
  const BatchProgressPanel({
    super.key,
    required this.isIdeogram,
    required this.processedImages,
    required this.totalImages,
    required this.isCancelling,
    required this.onStop,
    this.stepLabel,
  });

  final bool isIdeogram;
  final String? stepLabel;
  final int processedImages;
  final int totalImages;
  final bool isCancelling;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final Color progressBg = isIdeogram
        ? Colors.teal.withAlpha(100)
        : Colors.green.withAlpha(100);
    final Color progressFg = isIdeogram ? Colors.teal : Colors.green;

    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: progressBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const RiveProcessingIndicator(size: 15),
          const SizedBox(width: 8),
          if (stepLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                stepLabel!,
                style: TextStyle(
                  color: isIdeogram ? Colors.tealAccent : Colors.green,
                  fontSize: 11,
                ),
              ),
            ),
          Text(
            '$processedImages/$totalImages',
            style: TextStyle(
              color: progressFg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isCancelling) ...<Widget>[
            const SizedBox(width: 8),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

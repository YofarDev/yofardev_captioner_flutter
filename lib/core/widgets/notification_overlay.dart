import 'package:flutter/material.dart';

class NotificationOverlay {
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = Colors.black87,
    Color textColor = Colors.white,
  }) {
    final OverlayState overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    bool isVisible = false;

    overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          top: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: _NotificationWidget(
              message: message,
              backgroundColor: backgroundColor,
              textColor: textColor,
              onRemoved: () {
                if (isVisible) {
                  overlayEntry.remove();
                  isVisible = false;
                }
              },
            ),
          ),
        );
      },
    );

    overlayState.insert(overlayEntry);
    isVisible = true;

    // Auto-hide after duration
    Future<void>.delayed(duration, () {
      if (isVisible) {
        overlayEntry.remove();
        isVisible = false;
      }
    });
  }
}

class _NotificationWidget extends StatefulWidget {
  const _NotificationWidget({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.onRemoved,
  });

  final String message;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onRemoved;

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, -1.0), // Start from top-right
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.check_circle, color: widget.textColor, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(color: widget.textColor, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

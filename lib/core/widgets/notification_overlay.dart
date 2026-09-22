import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class NotificationOverlay {
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = panelRaised,
    Color textColor = textPrimary,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(radiusSm),
            border: Border.all(color: hairline),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.check_circle,
                color: widget.textColor == textPrimary
                    ? success
                    : widget.textColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'rive_animations.dart';

class AppButton extends StatelessWidget {
  final String text;
  final Function()? onTap;
  final bool isLoading;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final String? iconAssetPath;
  final IconData? iconData;
  final bool isOutline;

  const AppButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.foregroundColor,
    this.backgroundColor,
    this.iconAssetPath,
    this.iconData,
    this.isOutline = false,
  });

  Widget _buildChild() {
    if (isLoading) {
      return const RiveProcessingIndicator();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (iconAssetPath != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Image.asset(
              iconAssetPath!,
              width: 20,
              color: foregroundColor ?? buttonPrimaryFg,
            ),
          ),
        if (iconData != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              iconData,
              size: 16,
              color: foregroundColor ?? buttonPrimaryFg,
            ),
          ),
        Text(text, style: TextStyle(color: foregroundColor ?? buttonPrimaryFg)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color fg = foregroundColor ?? (isOutline
        ? buttonOutlineFg
        : buttonPrimaryFg);
    final Color? overlay = onTap == null ? null : fg.withValues(alpha: 0.12);

    if (isOutline) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: backgroundColor ?? buttonOutlineBorder),
          backgroundColor: Colors.transparent,
          overlayColor: overlay,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
        onPressed: isLoading ? null : onTap,
        child: _buildChild(),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: backgroundColor ?? buttonPrimaryBg,
        disabledBackgroundColor: panelRaised,
        disabledForegroundColor: buttonDisabledFg,
        overlayColor: overlay,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      onPressed: isLoading ? null : onTap,
      child: _buildChild(),
    );
  }
}

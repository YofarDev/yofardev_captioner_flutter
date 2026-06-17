import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

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
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(color: accentPink),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (iconAssetPath != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Image.asset(iconAssetPath!, width: 20),
          ),
        if (iconData != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              iconData,
              size: 16,
              color: foregroundColor ?? textPrimary,
            ),
          ),
        Text(text, style: TextStyle(color: foregroundColor ?? buttonPrimaryFg)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isOutline) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor ?? buttonOutlineFg,
          side: BorderSide(color: backgroundColor ?? buttonOutlineBorder),
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: isLoading ? null : onTap,
        child: _buildChild(),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: foregroundColor ?? buttonPrimaryFg,
        backgroundColor: backgroundColor ?? buttonPrimaryBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: isLoading ? null : onTap,
      child: _buildChild(),
    );
  }
}

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppButton extends StatelessWidget {
  final String text;
  final Function()? onTap;
  final bool isLoading;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final String? iconAssetPath;
  const AppButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.foregroundColor,
    this.backgroundColor,
    this.iconAssetPath,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? lightGrey,
      ),
      onPressed: onTap,
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: lightPink),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (iconAssetPath != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.asset(iconAssetPath!, width: 20),
                  ),
                Text(
                  text,
                  style: TextStyle(color: foregroundColor ?? Colors.white),
                ),
              ],
            ),
    );
  }
}

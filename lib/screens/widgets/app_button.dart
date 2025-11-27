import 'package:flutter/material.dart';

import '../../res/app_colors.dart';

class AppButton extends StatelessWidget {
  final String text;
  final Function()? onTap;
  final bool isLoading;
  final Color? foregroundColor;
  final Color? backgroundColor;
  const AppButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLoading = false,
    this.foregroundColor,
    this.backgroundColor,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: backgroundColor ?? lightGrey),
      onPressed: onTap,
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: lightPink),
            )
          : Text(text, style:  TextStyle(color: foregroundColor ?? Colors.white)),
    );
  }
}

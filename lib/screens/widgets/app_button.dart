import 'package:flutter/material.dart';

import '../../res/app_colors.dart';

class AppButton extends StatelessWidget {
  final String text;
  final Function()? onTap;
  final bool isLoading;
  const AppButton({
    super.key,
    required this.text,
    this.onTap,
    this.isLoading = false,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: lightGrey),
      onPressed: onTap,
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: lightPink),
            )
          : Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

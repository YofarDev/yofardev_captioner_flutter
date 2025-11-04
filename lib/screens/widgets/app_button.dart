import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String text;
  final Function()? onTap;

  const AppButton({super.key, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      onPressed: onTap,
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

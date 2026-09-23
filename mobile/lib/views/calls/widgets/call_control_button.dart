import 'package:flutter/material.dart';

class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.white24,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: iconColor, size: 26),
        ),
      ),
    );
  }
}

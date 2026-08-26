import 'package:flutter/material.dart';
import 'package:social_app/views/feeds/widgets/reel_text_shadow.dart';

class ReelAction extends StatelessWidget {
  const ReelAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 30, shadows: reelTextShadow),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: reelTextShadow,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Small circular "x" overlaid on a composer's media preview to clear
/// the attached photo/video.
class RemoveMediaButton extends StatelessWidget {
  const RemoveMediaButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
        ),
        child: const Icon(Icons.close, size: 18, color: Colors.white),
      ),
    );
  }
}

import 'package:flutter/material.dart';

const _backgroundColors = [
  Color(0xFF7C4DFF),
  Color(0xFF00BFA5),
  Color(0xFFFF6D00),
  Color(0xFFD500F9),
  Color(0xFF2979FF),
  Color(0xFFC51162),
  Color(0xFF00C853),
];

/// Full-bleed colored background for a text-only post, in the style of a
/// WhatsApp text status. The color is picked deterministically from the
/// text itself so the same post always renders the same color.
class TextBackground extends StatelessWidget {
  const TextBackground({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color =
        _backgroundColors[text.hashCode.abs() % _backgroundColors.length];

    return Container(
      color: color,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

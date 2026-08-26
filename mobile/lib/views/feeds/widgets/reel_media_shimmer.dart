import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Full-bleed loading placeholder for reel media. Colors are hardcoded
/// rather than theme-derived, matching the rest of the reel overlay
/// (see [ReelsTile]'s doc comment) since this sits over arbitrary media
/// instead of the app surface.
class ReelMediaShimmer extends StatelessWidget {
  const ReelMediaShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF3A3A3A),
      child: const ColoredBox(color: Colors.black),
    );
  }
}

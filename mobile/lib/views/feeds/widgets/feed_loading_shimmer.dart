import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton placeholder mirroring [ReelsTile]'s full-bleed media block
/// plus its bottom avatar/caption overlay, shown while the feed's first
/// page is still loading — fills whatever space its parent (a
/// [PageView] page) gives it, same as [ReelsTile] itself.
class FeedLoadingShimmer extends StatelessWidget {
  const FeedLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
            Positioned(
              left: 16,
              right: 72,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(radius: 18),
                      const SizedBox(width: 8),
                      Container(
                        width: 100,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(width: double.infinity, height: 12, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(width: 160, height: 12, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

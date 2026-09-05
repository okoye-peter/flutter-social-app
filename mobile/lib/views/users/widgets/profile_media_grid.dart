import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/models/post_model.dart';

const _brandColor = Color(0xFF0793F1);

/// Grid of media tiles shown inside one tab of the profile screen, backed
/// by real posts fetched via [ProfileBloc].
class ProfileMediaGrid extends StatelessWidget {
  const ProfileMediaGrid({
    super.key,
    required this.type,
    required this.items,
    this.onLoadMore,
  });

  final ProfileMediaType type;
  final List<PostModel> items;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Builder(
      builder: (innerContext) {
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(innerContext),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(type: type, colorScheme: colorScheme),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(1.5),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                    childAspectRatio: type == ProfileMediaType.reel ? 0.6 : 1,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    // Fire near the end of the grid rather than only on the
                    // very last tile, so the next page has time to arrive
                    // before the user actually scrolls that far.
                    if (index >= items.length - 6) onLoadMore?.call();
                    return _MediaTile(type: type, post: items[index]);
                  }, childCount: items.length),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown instead of [ProfileMediaGrid] when the viewer and this profile's
/// owner have blocked each other in either direction.
class ProfileBlockedTabState extends StatelessWidget {
  const ProfileBlockedTabState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child: Icon(Icons.block_rounded, size: 28, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const Text(
              'This content isn\'t available',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.type, required this.post});

  final ProfileMediaType type;
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.thumbnailUrl ?? post.mediaUrl ?? '';

    return GestureDetector(
      onTap: () => context.push(AppRoutes.feedDetailsPath(post.id), extra: post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Container(color: Colors.white),
            ),
            errorWidget: (context, url, error) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
          ),
          if (type == ProfileMediaType.reel)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    stops: const [0.6, 1],
                  ),
                ),
              ),
            ),
          if (type == ProfileMediaType.reel)
            const Positioned(
              left: 6,
              bottom: 6,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 15),
            ),
          if (type == ProfileMediaType.repost)
            const Positioned(
              top: 6,
              left: 6,
              child: _BadgeIcon(icon: Icons.repeat_rounded),
            ),
          if (type == ProfileMediaType.mention)
            const Positioned(
              top: 6,
              left: 6,
              child: _BadgeIcon(icon: Icons.alternate_email_rounded),
            ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: 20,
      decoration: const BoxDecoration(
        color: _brandColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.type, required this.colorScheme});

  final ProfileMediaType type;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (type) {
      ProfileMediaType.post => (
        Icons.grid_on_rounded,
        'No posts yet',
        'Shared photos and videos will appear here.',
      ),
      ProfileMediaType.reel => (
        Icons.movie_creation_outlined,
        'No reels yet',
        'Reels you create will show up here.',
      ),
      ProfileMediaType.repost => (
        Icons.repeat_rounded,
        'No reposts yet',
        'Posts you repost will be collected here.',
      ),
      ProfileMediaType.mention => (
        Icons.alternate_email_rounded,
        'No mentions yet',
        'Posts you\'re tagged in will appear here.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child: Icon(icon, size: 28, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/views/users/widgets/profile_header.dart';
import 'package:social_app/views/users/widgets/profile_media_grid.dart';

const _brandColor = Color(0xFF0793F1);

// Mock data only — no backend wiring. Replace with real values once the
// view model / bloc for this screen is ready.
const _mockName = 'Ava Michaels';
const _mockUsername = 'ava.codes';
const _mockAvatarUrl = 'https://picsum.photos/seed/ava-michaels/200/200';
const _mockBio =
    'Building beautiful things, one pixel at a time ✨\nFlutter developer';
const _mockLocation = 'Lagos, Nigeria';
const _mockPostCount = 128;
const _mockFollowerCount = '12.4K';
const _mockFollowingCount = '340';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                _mockUsername,
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {},
            ),
            IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () {}),
            const SizedBox(width: 4),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: ProfileHeader(
                  colorScheme: colorScheme,
                  avatarUrl: _mockAvatarUrl,
                  name: _mockName,
                  username: _mockUsername,
                  bio: _mockBio,
                  location: _mockLocation,
                  postCount: _mockPostCount,
                  followerCount: _mockFollowerCount,
                  followingCount: _mockFollowingCount,
                  isOwnProfile: true,
                ),
              ),
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: _ProfileTabBarDelegate(colorScheme: colorScheme),
                ),
              ),
            ];
          },
          body: const TabBarView(
            children: [
              ProfileMediaGrid(type: ProfileMediaType.post, itemCount: 18),
              ProfileMediaGrid(type: ProfileMediaType.reel, itemCount: 10),
              ProfileMediaGrid(type: ProfileMediaType.repost, itemCount: 6),
              ProfileMediaGrid(type: ProfileMediaType.mention, itemCount: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabBarDelegate({required this.colorScheme});

  final ColorScheme colorScheme;

  static const double _height = 46;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: TabBar(
        indicatorColor: _brandColor,
        indicatorWeight: 2.4,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: _brandColor,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        tabs: const [
          Tab(icon: Icon(Icons.grid_on_rounded, size: 23)),
          Tab(icon: Icon(Icons.movie_creation_outlined, size: 23)),
          Tab(icon: Icon(Icons.repeat_rounded, size: 23)),
          Tab(icon: Icon(Icons.alternate_email_rounded, size: 23)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabBarDelegate oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}

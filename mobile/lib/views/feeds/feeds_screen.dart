import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/views/feeds/widgets/reels_tile.dart';
import 'package:social_app/views/feeds/widgets/story_tile.dart';

// TODO: temporary sample used to test reels video playback — replace
// with a real Post.mediaUrl once the feed is wired to the backend.
const _sampleReelVideoUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

const _storyItemWidth = 80.0;
const _storyRowHeight = 120.0;
const _reelCardHeight = 800.0;

class FeedsScreen extends StatelessWidget {
  const FeedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final UserModel? user = getIt<UserCache>().current;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          // TODO: implement new post feature
          onPressed: () {},
          icon: Icon(Icons.add, color: theme.tabBarTheme.labelColor, size: 30),
        ),
        title: GestureDetector(
          // TODO: implement the user search
          onTap: () {},
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              //   border: isDarkMode ? Border.all(color: Color.fromARGB(122, 227, 227, 227)) : null,
              color: isDarkMode
                  ? theme.secondaryHeaderColor.withAlpha(125)
                  : Color.fromARGB(122, 227, 227, 227),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.search, size: 20, color: Colors.grey),
                  SizedBox(width: 10),
                  Text(
                    'Search...',
                    style: TextStyle(color: Colors.grey, fontSize: 17),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                // TODO: implement notification
                onPressed: () {},
                icon: Icon(
                  CupertinoIcons.bell,
                  color: theme.tabBarTheme.labelColor,
                  size: 25,
                ),
              ),
              const Positioned(
                top: 13,
                right: 16,
                child: SizedBox(
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: _storyRowHeight,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemExtent: _storyItemWidth,
                itemCount: 15,
                itemBuilder: (_, index) {
                  final isOwnStory = index == 0;
                  final hasSeen = index % 3 == 0;
                  return StoryTile(
                    avatarUrl: user?.image ?? '',
                    initials: user?.getInitials ?? '?',
                    label: isOwnStory ? 'Your story' : (user?.name ?? 'Friend'),
                    isOwnStory: isOwnStory,
                    hasUnseenStory: hasSeen,
                    onTap: () {},
                  );
                },
              ),
            ),
          ),
          // reels
          SliverFixedExtentList(
            itemExtent: _reelCardHeight,
            delegate: SliverChildBuilderDelegate(
              (_, int index) {
                // TODO: use the real post id once the feed is wired to
                // the backend, instead of this synthesized sample id.
                final reelId = 'sample-$index';
                return ReelsTile(
                  mediaUrl: _sampleReelVideoUrl,
                  mediaType: ReelMediaType.video,
                  mode: ReelInteractionMode.feed,
                  avatarUrl: user?.image ?? '',
                  username: user?.username ?? 'friend',
                  caption: 'Testing reels video playback 🎬',
                  soundTitle: '${user?.name ?? 'Friend'} · original audio',
                  likeCount: 128,
                  repostCount: 100,
                  commentCount: 42,
                  shareCount: 7,
                  onTapReel: () =>
                      context.push(AppRoutes.feedDetailsPath(reelId)),
                );
              },
              childCount: 5,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/story_model.dart';
import 'package:social_app/models/story_viewer_args.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/story_repository.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/viewmodels/stories/story_bloc.dart';
import 'package:social_app/views/feeds/widgets/reels_tile.dart';
import 'package:social_app/views/feeds/widgets/story_tile.dart';

// TODO: temporary sample used to test reels video playback — replace
// with a real Post.mediaUrl once the feed is wired to the backend.
const _sampleReelVideoUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

const _storyItemWidth = 80.0;
const _storyRowHeight = 120.0;
const _reelCardHeight = 800.0;

class FeedsScreen extends StatefulWidget {
  const FeedsScreen({super.key});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  final _storyRepository = StoryRepository();

  Future<void> _createStory(BuildContext context) async {
    final sharedStory = await context.push<bool>(AppRoutes.createStory);
    if (sharedStory == true && context.mounted) {
      context.read<StoryBloc>().add(const LoadStoryEvent());
    }
  }

  Future<void> _createFeeds() async {
    final sharedFeeds = await context.push<bool>(AppRoutes.createFeeds);
    if(sharedFeeds == true && mounted){
      context.read<StoryBloc>().add(const LoadStoryEvent());
    }
  }

  void _openStoryViewer(
    BuildContext context,
    List<StoryGroupModel> storyGroups,
    StoryGroupModel group,
  ) {
    final index = storyGroups.indexOf(group);
    context.push(
      AppRoutes.storyViewer,
      extra: StoryViewerArgs(
        groups: storyGroups,
        initialGroupIndex: index < 0 ? 0 : index,
        onStoryViewed: _storyRepository.markStoryViewed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StoryBloc()..add(const LoadStoryEvent()),
      child: BlocBuilder<StoryBloc, StoryState>(
        builder: (context, state) {
          final storyGroups = state is StoryLoadedState
              ? state.stories
              : const <StoryGroupModel>[];
          return _buildScaffold(context, storyGroups);
        },
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    List<StoryGroupModel> storyGroups,
  ) {
    final theme = Theme.of(context);
    final UserModel? user = getIt<UserCache>().current;
    final isDarkMode = theme.brightness == Brightness.dark;

    StoryGroupModel? myGroup;
    final otherGroups = <StoryGroupModel>[];
    for (final group in storyGroups) {
      if (group.user.id == user?.id) {
        myGroup = group;
      } else {
        otherGroups.add(group);
      }
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.push(AppRoutes.createFeeds),
          icon: Icon(Icons.add, color: theme.tabBarTheme.labelColor, size: 30),
        ),
        title: GestureDetector(
          onTap: () => context.push(AppRoutes.search),
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
              // stories — own tile always first (Instagram keeps the "add"
              // tile visible even with zero stories), then everyone else in
              // the order the backend already ranked them (unseen-first).
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemExtent: _storyItemWidth,
                itemCount: 1 + otherGroups.length,
                itemBuilder: (_, index) {
                  if (index == 0) {
                    final group = myGroup;
                    return StoryTile(
                      avatarUrl: user?.image ?? '',
                      initials: user?.getInitials ?? '?',
                      label: 'Your story',
                      isOwnStory: true,
                      hasUnseenStory: false,
                      onTap: () => group != null
                          ? _openStoryViewer(context, storyGroups, group)
                          : _createStory(context),
                      // The "+" badge always adds another story, regardless
                      // of whether the user already has one.
                      onAddTap: () => _createStory(context),
                    );
                  }
                  final group = otherGroups[index - 1];
                  return StoryTile(
                    avatarUrl: group.user.image,
                    initials: group.user.getInitials,
                    label: group.user.name,
                    isOwnStory: false,
                    hasUnseenStory: group.hasUnseen,
                    onTap: () => _openStoryViewer(context, storyGroups, group),
                  );
                },
              ),
            ),
          ),
          // reels
          SliverFixedExtentList(
            itemExtent: _reelCardHeight,
            delegate: SliverChildBuilderDelegate((_, int index) {
              // TODO: use the real post id once the feed is wired to
              // the backend, instead of this synthesized sample id.
              final reelId = 'sample-$index';
              return ReelsTile(
                mediaUrl: _sampleReelVideoUrl,
                mediaType: MediaType.video,
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
            }, childCount: 5),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/models/story_model.dart';
import 'package:social_app/models/story_viewer_args.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/story_repository.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/viewmodels/posts/post_bloc.dart';
import 'package:social_app/viewmodels/stories/story_bloc.dart';
import 'package:social_app/views/feeds/widgets/feed_loading_shimmer.dart';
import 'package:social_app/views/feeds/widgets/reels_tile.dart';
import 'package:social_app/views/feeds/widgets/story_tile.dart';

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

  Future<void> _createFeeds(BuildContext context) async {
    final sharedFeeds = await context.push<bool>(AppRoutes.createFeeds);
    if (sharedFeeds == true && context.mounted) {
      context.read<PostBloc>().add(const FetchPostsEvent());
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => StoryBloc()..add(const LoadStoryEvent())),
        BlocProvider(create: (_) => PostBloc()..add(const FetchPostsEvent())),
        // (_) => StoryBloc()..add(const LoadStoryEvent())
      ],
      child: Builder(
        builder: (context) {
          final storyState = context.watch<StoryBloc>().state;
          final postState = context.watch<PostBloc>().state;

          final storyGroups = storyState is StoryLoadedState
                              ? storyState.stories : const <StoryGroupModel>[];

          final posts = postState is PostsLoadedState
                              ? postState.posts : const <PostModel>[];

          return _buildScaffold(context, storyGroups, posts, postState);
        },
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    List<StoryGroupModel> storyGroups,
    List<PostModel> posts,
    PostState postState,
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
          onPressed: () => _createFeeds(context),
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
          if (postState is PostErrorState)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(postState.message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context
                          .read<PostBloc>()
                          .add(const FetchPostsEvent()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (postState is PostLoadingState && posts.isEmpty)
            SliverFixedExtentList(
              itemExtent: _reelCardHeight,
              delegate: SliverChildBuilderDelegate(
                (_, _) => FeedLoadingShimmer(cardHeight: _reelCardHeight),
                childCount: 2,
              ),
            )
          else
            SliverFixedExtentList(
              itemExtent: _reelCardHeight,
              delegate: SliverChildBuilderDelegate((_, int index) {
                final post = posts[index];
                return ReelsTile(
                  mediaUrl: post.mediaUrl,
                  mediaType: post.mediaType,
                  mode: ReelInteractionMode.feed,
                  avatarUrl: post.user?.image ?? '',
                  username: post.user?.username ?? 'friend',
                  caption: post.caption ?? '',
                  soundTitle: post.sound?.title,
                  likeCount: post.likesCount,
                  repostCount: post.repostsCount,
                  commentCount: post.commentsCount,
                  onTapReel: () => context.push(
                    AppRoutes.feedDetailsPath(post.id),
                    extra: post,
                  ),
                );
              }, childCount: posts.length),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/feed_item_model.dart';
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

class FeedsScreen extends StatefulWidget {
  const FeedsScreen({super.key});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  final _storyRepository = StoryRepository();

  /// Drives both the reels [PageView] and the header's collapse — its
  /// fractional `page` (0 while idle on the first reel, ramping to 1 as
  /// the user swipes into the second) is read directly as the collapse
  /// amount, so the header slides away in lockstep with that first swipe
  /// and stays hidden for every swipe after.
  final _reelsController = PageController();

  @override
  void dispose() {
    _reelsController.dispose();
    super.dispose();
  }

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

  Future<void> _openReelDetails(BuildContext context, PostModel post) async {
    final updated = await context.push<PostModel>(
      AppRoutes.feedDetailsPath(post.id),
      extra: post,
    );
    if (updated != null && context.mounted) {
      context.read<PostBloc>().add(SyncPostEvent(post: updated));
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
              ? storyState.stories
              : const <StoryGroupModel>[];

          final items = postState is PostsLoadedState
              ? postState.items
              : const <FeedItemModel>[];

          return _buildScaffold(context, storyGroups, items, postState);
        },
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    List<StoryGroupModel> storyGroups,
    List<FeedItemModel> items,
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

    // The story/app-bar header has its own real layout space at rest;
    // as the first swipe (page 0 → 1) drags it out, this Expanded's
    // reels area grows to reclaim that space, ending up full screen.
    final Widget reelsArea;
    if (postState is PostErrorState) {
      // No PageView here, so `_reelsController` stays unattached and the
      // header's collapse fraction naturally reads as 0 (fully shown).
      reelsArea = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(postState.message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    context.read<PostBloc>().add(const FetchPostsEvent()),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else {
      final isLoading = postState is PostLoadingState && items.isEmpty;
      reelsArea = PageView.builder(
        controller: _reelsController,
        scrollDirection: Axis.vertical,
        itemCount: isLoading ? 2 : items.length,
        onPageChanged: (index) {
          // FetchMovePostsEvent was previously never dispatched anywhere,
          // so the feed could never load past its first page — droppable()
          // on the bloc already guards against firing this again while a
          // fetch is still in flight.
          if (postState is! PostsLoadedState || !postState.hasMorePage) {
            return;
          }
          if (index >= items.length - 2) {
            context.read<PostBloc>().add(
              FetchMovePostsEvent(cursor: postState.nextCursor!),
            );
          }
        },
        itemBuilder: (_, int index) {
          if (isLoading) return const FeedLoadingShimmer();

          final feedItem = items[index];
          final post = feedItem.post;
          final repost = feedItem.repost;

          return ReelsTile(
            postId: post.id,
            mediaUrl: post.mediaUrl,
            mediaType: post.mediaType,
            mode: ReelInteractionMode.feed,
            avatarUrl: post.user?.image ?? post.user?.getInitials ?? '?',
            username: post.user?.username ?? 'friend',
            caption: post.caption ?? '',
            soundTitle: post.sound?.title,
            likeCount: post.likesCount,
            repostCount: post.repostsCount,
            commentCount: post.commentsCount,
            bookMarkCount: post.bookmarksCount,
            likedByMe: post.likedByMe,
            bookMarkedByMe: post.bookmarkedByMe,
            repostedByMe: post.repostedByMe,
            repostedByUsername: repost?.repostedBy.username,
            repostComment: repost?.comment,
            onTapLike: () => context.read<PostBloc>().toggleLike(post),
            onTapBookMark: () => context.read<PostBloc>().toggleBookMark(post),
            onTapRepost: () => context.read<PostBloc>().toggleRepost(post),
            onTapReel: () => _openReelDetails(context, post),
            onTapProfile: post.user != null
                ? () => context.push(
                    AppRoutes.profilePath(post.user!.id),
                    extra: post.user,
                  )
                : null,
          );
        },
      );
    }

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          centerTitle: true,
          leading: IconButton(
            onPressed: () => _createFeeds(context),
            icon: Icon(
              Icons.add,
              color: theme.tabBarTheme.labelColor,
              size: 30,
            ),
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
        Container(
          height: _storyRowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
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
      ],
    );

    final headerHeight =
        MediaQuery.paddingOf(context).top + kToolbarHeight + _storyRowHeight;

    return Scaffold(
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _reelsController,
            builder: (context, child) {
              final collapse = _reelsController.hasClients
                  ? (_reelsController.page ?? 0).clamp(0.0, 1.0)
                  : 0.0;
              // Reserves shrinking space in the Column (so the reels
              // Expanded below grows to fill it) while the header itself
              // rigidly slides upward within that shrinking window — the
              // app bar (top) exits first, the story row (bottom) last,
              // same order a normal scrolled-away header would use.
              return ClipRect(
                child: SizedBox(
                  height: headerHeight * (1 - collapse),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: headerHeight,
                    maxHeight: headerHeight,
                    child: Transform.translate(
                      offset: Offset(0, -headerHeight * collapse),
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: header,
          ),
          Expanded(child: reelsArea),
        ],
      ),
    );
  }
}

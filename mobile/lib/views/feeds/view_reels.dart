import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/viewmodels/posts/post_bloc.dart';
import 'package:social_app/views/feeds/widgets/reel_media_shimmer.dart';
import 'package:social_app/views/feeds/widgets/reels_tile.dart';

class ViewReelDetailsScreen extends StatelessWidget {
  const ViewReelDetailsScreen({
    super.key,
    required this.reelId,
    this.initialPost,
  });

  final String reelId;

  /// Passed via the route's `extra` when navigating in-app from a feed
  /// that already has the post loaded — skips the network round trip.
  /// Null when arriving via a deep link, so the screen fetches by
  /// [reelId] instead.
  final PostModel? initialPost;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = PostBloc();
        if (initialPost == null) {
          bloc.add(GetPostDetailsEvent(postId: reelId));
        }
        return bloc;
      },
      child: BlocBuilder<PostBloc, PostState>(
        builder: (context, state) {
          // Prefer the bloc's own post once it has one: it's kept fresh by
          // toggles (see _applyPost in PostBloc), whereas initialPost is a
          // one-time snapshot passed in via the route's `extra`.
          final post =
              (state is PostDetailsLoadedState ? state.post : null) ??
              initialPost;

          final Widget body;
          if (post != null) {
            body = _ReelDetails(post: post);
          } else if (state is PostErrorState) {
            body = _ErrorView(
              message: state.message,
              onRetry: () => context.read<PostBloc>().add(
                GetPostDetailsEvent(postId: reelId),
              ),
            );
          } else {
            body = const ReelMediaShimmer();
          }

          return Scaffold(
            body: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: body),
                  Positioned(
                    left: 4,
                    top: 4,
                    child: IconButton(
                      onPressed: () => context.pop(post),
                      icon: const Icon(
                        CupertinoIcons.back,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReelDetails extends StatelessWidget {
  const _ReelDetails({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    return ReelsTile(
      postId: post.id,
      mediaUrl: post.mediaUrl,
      mediaType: post.mediaType,
      mode: ReelInteractionMode.details,
      avatarUrl: post.user?.image ?? post.user?.getInitials ?? '?',
      username: post.user?.username ?? 'friend',
      caption: post.caption ?? '',
      soundTitle: post.sound?.title,
      // ReelsTile asserts soundUrl is only passed for image/text posts —
      // video posts play their own embedded audio track instead.
      soundUrl: post.mediaType == MediaType.video ? null : post.sound?.audioUrl,
      likeCount: post.likesCount,
      repostCount: post.repostsCount,
      commentCount: post.commentsCount,
      bookMarkCount: post.bookmarksCount,
      likedByMe: post.likedByMe,
      bookMarkedByMe: post.bookmarkedByMe,
      repostedByMe: post.repostedByMe,
      onTapLike: () => context.read<PostBloc>().toggleLike(post),
      onTapBookMark: () => context.read<PostBloc>().toggleBookMark(post),
      onTapRepost: () => context.read<PostBloc>().toggleRepost(post),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

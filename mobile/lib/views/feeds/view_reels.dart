import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/viewmodels/posts/post_bloc.dart';
import 'package:social_app/views/feeds/widgets/reel_media_shimmer.dart';
import 'package:social_app/views/feeds/widgets/reels_tile.dart';

class ViewReelDetailsScreen extends StatefulWidget {
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
  State<ViewReelDetailsScreen> createState() => _ViewReelDetailsScreenState();
}

class _ViewReelDetailsScreenState extends State<ViewReelDetailsScreen> {
  late final PostBloc _postBloc;

  @override
  void initState() {
    super.initState();
    _postBloc = PostBloc();
    if (widget.initialPost == null) {
      _postBloc.add(GetPostDetailsEvent(postId: widget.reelId));
    }
  }

  @override
  void dispose() {
    _postBloc.close();
    super.dispose();
  }

  void _retry() => _postBloc.add(GetPostDetailsEvent(postId: widget.reelId));

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _postBloc,
      child: BlocBuilder<PostBloc, PostState>(
        builder: (context, state) {
          final post =
              widget.initialPost ??
              (state is PostDetailsLoadedState ? state.post : null);

          final Widget body;
          if (post != null) {
            body = _ReelDetails(post: post);
          } else if (state is PostErrorState) {
            body = _ErrorView(message: state.message, onRetry: _retry);
          } else {
            body = const ReelMediaShimmer();
          }

          return Scaffold(
            body: SafeArea(
              child: Stack(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    child: body,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: IconButton(
                      onPressed: () => context.pop(),
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
      mediaUrl: post.mediaUrl,
      mediaType: post.mediaType,
      mode: ReelInteractionMode.details,
      avatarUrl: post.user?.image ?? '',
      username: post.user?.username ?? 'friend',
      caption: post.caption ?? '',
      soundTitle: post.sound?.title,
      likeCount: post.likesCount,
      repostCount: post.repostsCount,
      commentCount: post.commentsCount,
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/models/comment_model.dart';
import 'package:social_app/viewmodels/comments/comment_bloc.dart';
import 'package:social_app/views/feeds/widgets/comment_tile.dart';

/// Renders the loading/error/empty/list states for [CommentBloc] inside
/// [CommentBottomSheet], including the reply threads and pagination.
class CommentListBody extends StatelessWidget {
  const CommentListBody({
    super.key,
    required this.state,
    required this.scrollController,
    required this.postId,
    required this.expandedReplyIds,
    required this.onScrollNotification,
    required this.onToggleLike,
    required this.onReply,
    required this.onToggleReplies,
    required this.onLoadMoreReplies,
  });

  final CommentState state;
  final ScrollController scrollController;
  final String postId;
  final Set<String> expandedReplyIds;
  final bool Function(ScrollNotification, CommentState) onScrollNotification;
  final ValueChanged<CommentModel> onToggleLike;
  final ValueChanged<CommentModel> onReply;
  final ValueChanged<CommentModel> onToggleReplies;
  final void Function(CommentModel comment, String cursor) onLoadMoreReplies;

  @override
  Widget build(BuildContext context) {
    if (state is CommentInitialState || state is CommentLoadingState) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is CommentErrorState) {
      final message = (state as CommentErrorState).message;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context
                    .read<CommentBloc>()
                    .add(LoadCommentEvent(postId: postId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final loaded = state as CommentLoadedState;
    if (loaded.comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              const Text(
                'No comments yet',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Start the conversation.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) => onScrollNotification(notification, loaded),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: loaded.comments.length + (loaded.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= loaded.comments.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            );
          }

          final comment = loaded.comments[index];
          final isExpanded = expandedReplyIds.contains(comment.id);
          final repliesPage = loaded.repliesByParentId[comment.id];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommentTile(
                  comment: comment,
                  onToggleLike: () => onToggleLike(comment),
                  onReply: () => onReply(comment),
                  onToggleReplies: () => onToggleReplies(comment),
                  isRepliesExpanded: isExpanded,
                ),
                if (isExpanded) ...[
                  if (repliesPage == null)
                    const Padding(
                      padding: EdgeInsets.only(left: 44, top: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    for (final reply in repliesPage.items)
                      Padding(
                        padding: const EdgeInsets.only(left: 44, top: 12),
                        child: CommentTile(
                          comment: reply,
                          isReply: true,
                          onToggleLike: () => onToggleLike(reply),
                        ),
                      ),
                    if (repliesPage.hasMorePage)
                      Padding(
                        padding: const EdgeInsets.only(left: 44, top: 8),
                        child: TextButton(
                          onPressed: () =>
                              onLoadMoreReplies(comment, repliesPage.nextCursor!),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Load more replies'),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/comment_model.dart';

/// A single comment (or reply) row: avatar, username + text, like/reply
/// actions, and the reply-thread toggle.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.onToggleLike,
    this.onReply,
    this.onToggleReplies,
    this.isRepliesExpanded = false,
    this.isReply = false,
  });

  final CommentModel comment;
  final VoidCallback onToggleLike;
  final VoidCallback? onReply;
  final VoidCallback? onToggleReplies;
  final bool isRepliesExpanded;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarSource = comment.user?.image.isNotEmpty == true
        ? comment.user!.image
        : (comment.user?.getInitials ?? '?');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          source: avatarSource,
          radius: isReply ? 14 : 18,
          backgroundColor: colorScheme.surfaceContainerHighest,
          textColor: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  children: [
                    TextSpan(
                      text: '${comment.user?.username ?? 'user'}  ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: comment.content),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    timeAgo(comment.createdAt),
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  if (comment.likesCount > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${comment.likesCount} like${comment.likesCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (onReply != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (onToggleReplies != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onToggleReplies,
                  child: Text(
                    isRepliesExpanded ? 'Hide replies' : 'View replies',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onToggleLike,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              comment.likedByMe ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: comment.likedByMe ? Colors.redAccent : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

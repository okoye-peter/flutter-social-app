import 'package:flutter/material.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/core/widgets/follow_button.dart';
import 'package:social_app/core/widgets/user_avatar.dart';

/// A tappable row for one user in search results: avatar, name, username,
/// follower count, and an optional Follow/Following action.
class UserSearchCard extends StatelessWidget {
  const UserSearchCard({
    super.key,
    required this.name,
    required this.username,
    required this.imageUrl,
    required this.onTap,
    this.followersCount = 0,
    this.isFollowing = false,
    this.onFollowToggle,
  });

  final String name;
  final String username;
  final String imageUrl;
  final VoidCallback onTap;
  final int followersCount;
  final bool isFollowing;
  final VoidCallback? onFollowToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              UserAvatar(
                source: imageUrl.trim().isNotEmpty
                    ? imageUrl
                    : (name.isNotEmpty ? name[0].toUpperCase() : '?'),
                radius: 24,
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      followersCount > 0
                          ? '@$username · ${formatCount(followersCount)} followers'
                          : '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (onFollowToggle != null) ...[
                const SizedBox(width: 10),
                FollowButton(isFollowing: isFollowing, onTap: onFollowToggle!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:social_app/core/widgets/user_avatar.dart';

const _brandColor = Color(0xFF0793F1);
const _avatarSize = 60.0;
const _ringGap = 3.0;
const _ringWidth = 2.5;

/// One tile in the horizontal stories row at the top of the feed —
/// avatar with a gradient "unseen" ring, name label, and (for the
/// user's own story) an add badge.
class StoryTile extends StatelessWidget {
  const StoryTile({
    super.key,
    required this.avatarUrl,
    required this.initials,
    required this.label,
    required this.isOwnStory,
    required this.hasUnseenStory,
    required this.onTap,
    this.onAddTap,
  });

  final String avatarUrl;
  final String initials;
  final String label;
  final bool isOwnStory;
  final bool hasUnseenStory;

  /// Tap target for the avatar/ring and label. For another user's tile
  /// this opens their story viewer. For the own tile, once real story
  /// data is wired in, this should open the viewer when the user already
  /// has one or more active stories (a user can post many, grouped like a
  /// WhatsApp status) — [onAddTap] is the separate, always-add target.
  final VoidCallback onTap;

  /// Tap target for the own-story "+" badge only — always opens story
  /// creation, regardless of whether the user already has active stories.
  /// Falls back to [onTap] when not provided (e.g. before that add-vs-view
  /// distinction has real data behind it).
  final VoidCallback? onAddTap;

  static const _ringDiameter = _avatarSize + (_ringGap + _ringWidth) * 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _ringDiameter,
              height: _ringDiameter,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: !isOwnStory && hasUnseenStory
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _brandColor,
                                _brandColor.withValues(alpha: 0.4),
                              ],
                            )
                          : null,
                      border: !isOwnStory && hasUnseenStory
                          ? null
                          : Border.all(color: theme.dividerColor, width: 1.5),
                    ),
                    padding: EdgeInsets.all(_ringWidth),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: backgroundColor,
                      ),
                      padding: const EdgeInsets.all(_ringGap),
                      child: UserAvatar(
                        source: avatarUrl.trim().isNotEmpty
                            ? avatarUrl
                            : initials,
                        radius: _avatarSize / 2,
                        backgroundColor: theme.highlightColor,
                        textColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  
                  if (isOwnStory)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onAddTap ?? onTap,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: backgroundColor,
                          ),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: _brandColor,
                            child: Icon(Icons.add, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isOwnStory ? FontWeight.w600 : FontWeight.w400,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

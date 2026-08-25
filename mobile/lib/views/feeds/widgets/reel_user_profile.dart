import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/views/feeds/widgets/reel_text_shadow.dart';

/// Bottom-left overlay on a `ReelsTile` — profile row (avatar, username,
/// follow button), caption, and attached-sound label.
class ReelUserProfile extends StatelessWidget {
  const ReelUserProfile({
    super.key,
    required this.avatarUrl,
    required this.username,
    required this.isFollowing,
    required this.mediaType,
    required this.caption,
    this.soundTitle,
    this.onTapProfile,
    this.onTapFollow,
  });

  final String avatarUrl;
  final String username;
  final bool isFollowing;
  final MediaType mediaType;
  final String caption;
  final String? soundTitle;
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapFollow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.chats),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onTapProfile,
                child: UserAvatar(
                  source: avatarUrl.trim().isNotEmpty
                      ? avatarUrl
                      : (username.isNotEmpty ? username[0].toUpperCase() : '?'),
                  radius: 24,
                ),
              ),
              const SizedBox(width: 6),
              // Expanded(
              //   child: 
                GestureDetector(
                  onTap: onTapProfile,
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      shadows: reelTextShadow,
                    ),
                  ),
                ),
              // ),
              const SizedBox(width: 4),
              if (!isFollowing)
                OutlinedButton(
                  onPressed: onTapFollow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Follow',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (mediaType != MediaType.text && caption.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                shadows: reelTextShadow,
              ),
            ),
          ],
          if (soundTitle != null && soundTitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.music_note,
                  size: 14,
                  color: Colors.white,
                  shadows: reelTextShadow,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    soundTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: reelTextShadow,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

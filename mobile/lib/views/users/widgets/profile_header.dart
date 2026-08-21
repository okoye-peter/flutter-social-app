import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _brandColor = Color(0xFF0793F1);

/// Avatar, stats row, bio and action buttons shown at the top of the
/// profile screen, above the tab bar.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.colorScheme,
    required this.avatarUrl,
    required this.name,
    required this.username,
    required this.bio,
    required this.location,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.isOwnProfile,
  });

  final ColorScheme colorScheme;
  final String avatarUrl;
  final String name;
  final String username;
  final String bio;
  final String location;
  final int postCount;
  final String followerCount;
  final String followingCount;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(colorScheme: colorScheme, avatarUrl: avatarUrl, name: name),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatColumn(value: '$postCount', label: 'Posts'),
                    _StatColumn(value: followerCount, label: 'Followers'),
                    _StatColumn(value: followingCount, label: 'Following'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            '@$username',
            style: TextStyle(fontSize: 13.5, color: colorScheme.onSurfaceVariant),
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bio, style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ],
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: isOwnProfile
                    ? _OutlinedActionButton(
                        label: 'Edit profile',
                        icon: Icons.edit_outlined,
                        colorScheme: colorScheme,
                        onTap: () {},
                      )
                    : _FilledActionButton(label: 'Follow', onTap: () {}),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlinedActionButton(
                  label: isOwnProfile ? 'Share profile' : 'Message',
                  icon: isOwnProfile
                      ? Icons.ios_share_rounded
                      : Icons.mail_outline_rounded,
                  colorScheme: colorScheme,
                  onTap: () {},
                ),
              ),
              if (!isOwnProfile) ...[
                const SizedBox(width: 10),
                _IconSquareButton(
                  icon: Icons.more_horiz_rounded,
                  colorScheme: colorScheme,
                  onTap: () {},
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.colorScheme,
    required this.avatarUrl,
    required this.name,
  });

  final ColorScheme colorScheme;
  final String avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandColor, _brandColor.withValues(alpha: 0.4)],
        ),
      ),
      child: CircleAvatar(
        radius: 38,
        backgroundColor: colorScheme.surface,
        child: CircleAvatar(
          radius: 35,
          backgroundColor: colorScheme.surfaceContainerHighest,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
          onBackgroundImageError: (_, _) {},
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({
    required this.label,
    required this.icon,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      ),
    );
  }
}

class _FilledActionButton extends StatelessWidget {
  const _FilledActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _brandColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  const _IconSquareButton({
    required this.icon,
    required this.colorScheme,
    required this.onTap,
  });

  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      width: 38,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

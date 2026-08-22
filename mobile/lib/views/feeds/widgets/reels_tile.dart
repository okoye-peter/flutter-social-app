import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/views/feeds/widgets/image_background.dart';
import 'package:social_app/views/feeds/widgets/reel_action.dart';
import 'package:social_app/views/feeds/widgets/reel_media_shimmer.dart';
import 'package:social_app/views/feeds/widgets/reel_text_shadow.dart';
import 'package:social_app/views/feeds/widgets/reel_user_profile.dart';
import 'package:social_app/views/feeds/widgets/round_icon_button.dart';
import 'package:social_app/views/feeds/widgets/text_background.dart';
import 'package:social_app/views/feeds/widgets/video_background.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A reel pauses once less than this fraction of it is on-screen, and
/// resumes once it crosses back above it — the standard TikTok/Reels
/// threshold for viewport-based autoplay.
const _visibilityPlayThreshold = 0.6;

/// Mirrors the backend `MediaType` enum (see prisma/schema.prisma).
enum ReelMediaType { text, image, video }

/// Where a [ReelsTile] is being shown — controls what tap/double-tap do,
/// since the two contexts want different gestures for the same area:
/// - [feed]: tap opens the reel's details page, double-tap mutes.
/// - [details]: tap toggles play/pause, double-tap toggles like.
enum ReelInteractionMode { feed, details }

/// A single full-bleed reel — an autoplaying looped video, a static
/// image, or a WhatsApp-style text post — with an Instagram-style right
/// action rail and a bottom profile/caption overlay. Text here is always
/// white-on-scrim rather than theme-derived, since it sits over
/// arbitrary media instead of the app surface.
class ReelsTile extends StatefulWidget {
  const ReelsTile({
    super.key,
    this.mediaUrl,
    required this.mediaType,
    required this.mode,
    required this.avatarUrl,
    required this.username,
    required this.caption,
    this.soundTitle,
    this.soundUrl,
    this.isFollowing = false,
    this.likeCount = 0,
    this.repostCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.onTapReel,
    this.onTapProfile,
    this.onTapFollow,
    this.onTapLike,
    this.onTapComment,
    this.onTapShare,
  }) : assert(
         mediaType == ReelMediaType.text || mediaUrl != null,
         'mediaUrl is required for image/video posts',
       ),
       assert(
         soundUrl == null || mediaType != ReelMediaType.video,
         'video posts play their own embedded audio; pass soundUrl only '
         'for image/text posts',
       );

  /// Null for text posts; required for image/video posts.
  final String? mediaUrl;
  final ReelMediaType mediaType;
  final ReelInteractionMode mode;
  final String avatarUrl;
  final String username;
  final String caption;

  /// Display label for the music-note row, e.g. "Alice · original audio".
  /// Null when the post has no attached sound.
  final String? soundTitle;

  /// Playable audio for the attached [Sound]. Only meaningful for
  /// image/text posts — video posts play their own embedded audio via
  /// [mediaUrl] instead.
  final String? soundUrl;
  final bool isFollowing;
  final int likeCount;
  final int repostCount;
  final int commentCount;
  final int shareCount;

  /// Feed mode only — called when the reel is tapped to open its
  /// details page.
  final VoidCallback? onTapReel;
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapFollow;
  final VoidCallback? onTapLike;
  final VoidCallback? onTapComment;
  final VoidCallback? onTapShare;

  @override
  State<ReelsTile> createState() => _ReelsTileState();
}

class _ReelsTileState extends State<ReelsTile> {
  VideoPlayerController? _controller;
  AudioPlayer? _audioPlayer;
  bool _isMuted = true;
  bool _isLiked = false;
  bool _isVisible = true;
  late int _likeCount = widget.likeCount;
  late bool _isFollowing = widget.isFollowing;

  /// Stable across rebuilds (unlike a key generated inline in build),
  /// which [VisibilityDetector] needs to track this reel's visibility
  /// history correctly.
  final Key _visibilityKey = UniqueKey();

  bool get _isVideo => widget.mediaType == ReelMediaType.video;

  /// A standalone [Sound] attached to an image/text post — as opposed to
  /// a video's own embedded audio, which plays through [_controller].
  bool get _hasSound => !_isVideo && widget.soundUrl != null;

  bool get _hasAudio => _isVideo || _hasSound;

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl!))
            ..setLooping(true)
            ..setVolume(0)
            ..initialize().then((_) {
              if (!mounted) return;
              setState(() {});
              _controller!.play();
            });
    } else if (_hasSound) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.setLoopMode(LoopMode.one);
      _audioPlayer!.setVolume(0);
      _audioPlayer!.setUrl(widget.soundUrl!).then((_) {
        if (!mounted) return;
        _audioPlayer!.play();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller != null) {
      if (!controller.value.isInitialized) return;
      setState(() {
        controller.value.isPlaying ? controller.pause() : controller.play();
      });
      return;
    }

    final audioPlayer = _audioPlayer;
    if (audioPlayer != null) {
      setState(() {
        audioPlayer.playing ? audioPlayer.pause() : audioPlayer.play();
      });
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final isVisible = info.visibleFraction >= _visibilityPlayThreshold;
    if (isVisible == _isVisible) return;
    setState(() => _isVisible = isVisible);
    if (isVisible) {
      _controller?.play();
      _audioPlayer?.play();
    } else {
      _controller?.pause();
      _audioPlayer?.pause();
    }
  }

  void _toggleMute() {
    if (!_hasAudio) return;
    setState(() {
      _isMuted = !_isMuted;
      final volume = _isMuted ? 0.0 : 1.0;
      _controller?.setVolume(volume);
      _audioPlayer?.setVolume(volume);
    });
  }

  void _handleTap() {
    if (widget.mode == ReelInteractionMode.feed) {
      widget.onTapReel?.call();
      return;
    }
    if (_hasAudio) _togglePlayPause();
  }

  void _handleDoubleTap() {
    if (widget.mode == ReelInteractionMode.feed) {
      _toggleMute();
    } else {
      _toggleLike();
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    widget.onTapLike?.call();
  }

  void _toggleFollow() {
    setState(() => _isFollowing = !_isFollowing);
    widget.onTapFollow?.call();
  }

  Widget _buildBackground() {
    switch (widget.mediaType) {
      case ReelMediaType.video:
        final controller = _controller;
        return controller != null
            ? VideoBackground(controller: controller)
            : const ColoredBox(color: Colors.black);
      case ReelMediaType.image:
        return ImageBackground(imageUrl: widget.mediaUrl!);
      case ReelMediaType.text:
        return TextBackground(text: widget.caption);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: GestureDetector(
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        child: SizedBox(
          height: double.infinity,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // reels content
              _buildBackground(),

              if (_isVideo &&
                  controller != null &&
                  controller.value.isInitialized &&
                  !controller.value.isPlaying)
                const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 72,
                    color: Colors.white70,
                    shadows: reelTextShadow,
                  ),
                ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 220,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_hasAudio)
                Positioned(
                  top: 12,
                  right: 12,
                  child: RoundIconButton(
                    icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                    onTap: _toggleMute,
                  ),
                ),

              Positioned(
                right: 8,
                bottom: 200,
                child: Column(
                  children: [
                    // like
                    ReelAction(
                      icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                      iconColor: _isLiked ? Colors.redAccent : Colors.white,
                      label: formatCount(_likeCount),
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 18),
                    // comment
                    ReelAction(
                      icon: CupertinoIcons.chat_bubble,
                      label: formatCount(widget.commentCount),
                      onTap: () => widget.onTapComment?.call(),
                    ),
                    const SizedBox(height: 18),
                    // share
                    ReelAction(
                      icon: CupertinoIcons.paperplane,
                      label: formatCount(widget.shareCount),
                      onTap: () => widget.onTapShare?.call(),
                    ),
                    const SizedBox(height: 18),
                    ReelAction(
                      icon: CupertinoIcons.arrow_2_squarepath,
                      label: formatCount(widget.repostCount),
                      onTap: () => widget.onTapShare?.call(),
                    ),
                    const SizedBox(height: 18),

                    GestureDetector(
                      onTap: widget.onTapProfile,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ClipOval(
                          child: widget.avatarUrl.trim().isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.avatarUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const ReelMediaShimmer(),
                                  errorWidget: (context, url, error) =>
                                      const ColoredBox(color: Colors.white24),
                                )
                              : const ColoredBox(color: Colors.white24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // reel user profile
              Positioned(
                left: 12,
                right: 72,
                bottom: 16,
                child: ReelUserProfile(
                  avatarUrl: widget.avatarUrl,
                  username: widget.username,
                  isFollowing: _isFollowing,
                  mediaType: widget.mediaType,
                  caption: widget.caption,
                  soundTitle: widget.soundTitle,
                  onTapProfile: widget.onTapProfile,
                  onTapFollow: _toggleFollow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

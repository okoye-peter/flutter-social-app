import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:social_app/core/constants/api_constants.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/views/feeds/widgets/comment_modal.dart';
import 'package:social_app/views/feeds/widgets/image_background.dart';
import 'package:social_app/views/feeds/widgets/reel_action.dart';
import 'package:social_app/core/enums/app_enums.dart';
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

/// A single full-bleed reel — an autoplaying looped video, a static
/// image, or a WhatsApp-style text post — with an Instagram-style right
/// action rail and a bottom profile/caption overlay. Text here is always
/// white-on-scrim rather than theme-derived, since it sits over
/// arbitrary media instead of the app surface.
class ReelsTile extends StatefulWidget {
  const ReelsTile({
    super.key,
    required this.postId,
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
    this.bookMarkCount = 0,
    this.onTapReel,
    this.onTapProfile,
    this.onTapFollow,
    this.onTapLike,
    this.onTapBookMark,
    this.onTapRepost,
    this.likedByMe = false,
    this.bookMarkedByMe = false,
    this.repostedByMe = false,
    this.repostedByUsername,
    this.repostComment,
  }) : assert(
         mediaType == MediaType.text || mediaUrl != null,
         'mediaUrl is required for image/video posts',
       ),
       assert(
         soundUrl == null || mediaType != MediaType.video,
         'video posts play their own embedded audio; pass soundUrl only '
         'for image/text posts',
       );

  final String postId;

  /// Null for text posts; required for image/video posts.
  final String? mediaUrl;
  final MediaType mediaType;
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
  final int bookMarkCount;

  /// Feed mode only — called when the reel is tapped to open its
  /// details page.
  final VoidCallback? onTapReel;
  final VoidCallback? onTapProfile;
  final VoidCallback? onTapFollow;
  final Future<void> Function()? onTapLike;
  final Future<void> Function()? onTapBookMark;
  final Future<void> Function()? onTapRepost;

  final bool likedByMe;
  final bool bookMarkedByMe;
  final bool repostedByMe;

  /// Feed mode only — non-null when this tile is showing because
  /// [repostedByUsername] reposted it, rather than being the viewer's own
  /// following of the original author. A quote-repost also sets
  /// [repostComment]; a plain repost leaves it null.
  final String? repostedByUsername;
  final String? repostComment;

  @override
  State<ReelsTile> createState() => _ReelsTileState();
}

class _ReelsTileState extends State<ReelsTile> {
  static const _videoLoadTimeout = Duration(seconds: 12);

  VideoPlayerController? _controller;
  AudioPlayer? _audioPlayer;
  bool _isMuted = true;
  late bool _isLiked = widget.likedByMe;
  late bool _isBookMarked = widget.bookMarkedByMe;
  late bool _isReposted = widget.repostedByMe;
  bool _isVisible = true;
  bool _hasVideoError = false;
  bool _isLikeSubmitting = false;
  late int _likeCount = widget.likeCount;
  bool _isBookMarkSubmitting = false;
  late int _bookMarkCount = widget.bookMarkCount;
  bool _isRepostSubmitting = false;
  late int _repostCount = widget.repostCount;
  late int _commentCount = widget.commentCount;
  late bool _isFollowing = widget.isFollowing;

  /// Stable across rebuilds (unlike a key generated inline in build),
  /// which [VisibilityDetector] needs to track this reel's visibility
  /// history correctly.
  final Key _visibilityKey = UniqueKey();

  bool get _isVideo => widget.mediaType == MediaType.video;

  /// A standalone [Sound] attached to an image/text post — as opposed to
  /// a video's own embedded audio, which plays through [_controller].
  bool get _hasSound => !_isVideo && widget.soundUrl != null;

  bool get _hasAudio => _isVideo || _hasSound;

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initVideo();
    } else if (_hasSound) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.setLoopMode(LoopMode.one);
      _audioPlayer!.setVolume(0);
      _audioPlayer!.setUrl(widget.soundUrl!).then((_) {
        if (!mounted) return;
        if (_isVisible) _audioPlayer!.play();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    setState(() => _hasVideoError = false);
    final controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl!))
          ..setLooping(true)
          ..setVolume(0);
    _controller = controller;
    try {
      await controller.initialize().timeout(_videoLoadTimeout);
    } catch (_) {
      controller.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _hasVideoError = true;
      });
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {});
    if (_isVisible) controller.play();
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
    if (!mounted) return;
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
    if (_hasVideoError) {
      _initVideo();
      return;
    }
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

  Future<void> _toggleLike() async {
    if (_isLikeSubmitting) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      _isLikeSubmitting = true;
    });
    await widget.onTapLike?.call();
    if (mounted) setState(() => _isLikeSubmitting = false);
  }

  Future<void> _toggleBookMark() async {
    if (_isBookMarkSubmitting) return;
    setState(() {
      _isBookMarked = !_isBookMarked;
      _bookMarkCount += _isBookMarked ? 1 : -1;
      _isBookMarkSubmitting = true;
    });
    await widget.onTapBookMark?.call();
    if (mounted) setState(() => _isBookMarkSubmitting = false);
  }

  Future<void> _toggleRepost() async {
    if (_isRepostSubmitting) return;
    setState(() {
      _isReposted = !_isReposted;
      _repostCount += _isReposted ? 1 : -1;
      _isRepostSubmitting = true;
    });
    await widget.onTapRepost?.call();
    if (mounted) setState(() => _isRepostSubmitting = false);
  }

  void _toggleFollow() {
    setState(() => _isFollowing = !_isFollowing);
    widget.onTapFollow?.call();
  }

  void _shareReel() {
    // The public /share/posts/:id page carries Open Graph tags, so apps
    // like WhatsApp/Twitter render a rich preview card for this link
    // rather than plain text.
    final url = '${ApiConstants.appUrl}/share/posts/${widget.postId}';
    final caption = widget.caption.trim();
    final captionSuffix = caption.isEmpty ? '' : ': $caption';
    final text =
        'Check out this post by ${widget.username} on Social App$captionSuffix\n$url';
    // Anchors the iPad share popover to this tile; ignored on other
    // platforms.
    final box = context.findRenderObject() as RenderBox?;
    SharePlus.instance.share(
      ShareParams(
        text: text,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }

  Widget _buildBackground() {
    switch (widget.mediaType) {
      case MediaType.video:
        if (_hasVideoError) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 40),
                  SizedBox(height: 12),
                  Text(
                    "Couldn't load video\nTap to retry",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }
        final controller = _controller;
        return controller != null
            ? VideoBackground(controller: controller)
            : const ColoredBox(color: Colors.black);
      case MediaType.image:
        return ImageBackground(imageUrl: widget.mediaUrl!);
      case MediaType.text:
        return TextBackground(text: widget.caption);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final theme = Theme.of(context);
    // Feed mode renders this tile full-bleed with no ambient SafeArea
    // (the collapsing header only reserves top space for the first
    // reel), so top-anchored overlays must clear the status bar
    // themselves. In details mode the parent already wraps this in a
    // SafeArea, where this padding correctly reads as 0.
    final topInset = MediaQuery.paddingOf(context).top;

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Tap/double-tap live on the background layer only, as a
            // Stack sibling of the overlay buttons below rather than
            // their ancestor — an ancestor GestureDetector here would
            // otherwise compete with (and can starve) a button's own
            // tap in the gesture arena, since onDoubleTap forces every
            // tap in its subtree to wait out the double-tap window.
            GestureDetector(
              onTap: _handleTap,
              onDoubleTap: _handleDoubleTap,
              behavior: HitTestBehavior.opaque,
              child: _buildBackground(),
            ),

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
                top: 12 + topInset,
                right: 12,
                child: RoundIconButton(
                  icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                  onTap: _toggleMute,
                ),
              ),

            if (widget.repostedByUsername != null)
              Positioned(
                top: 12 + topInset,
                left: 12,
                right: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.repeat,
                          size: 14,
                          color: Colors.white,
                          shadows: reelTextShadow,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Reposted by ${widget.repostedByUsername}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              shadows: reelTextShadow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.repostComment != null &&
                        widget.repostComment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.repostComment!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            Positioned(
              right: 8,
              bottom: 120,
              child: Column(
                children: [
                  // like
                  _isLikeSubmitting
                      ? const SizedBox(
                          width: 30,
                          height: 46,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : ReelAction(
                          icon: _isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          iconColor: _isLiked ? Colors.redAccent : Colors.white,
                          label: formatCount(_likeCount),
                          onTap: _toggleLike,
                        ),
                  const SizedBox(height: 18),
                  // comment
                  ReelAction(
                    icon: CupertinoIcons.chat_bubble,
                    label: formatCount(_commentCount),
                    onTap: () => CommentBottomSheet.show(
                      context,
                      postId: widget.postId,
                      onCommentPosted: () => setState(() => _commentCount++),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // share
                  ReelAction(
                    icon: CupertinoIcons.paperplane,
                    label: formatCount(widget.shareCount),
                    onTap: _shareReel,
                  ),
                  const SizedBox(height: 18),
                  // bookmark
                  _isBookMarkSubmitting
                      ? const SizedBox(
                          width: 30,
                          height: 46,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : ReelAction(
                          icon: _isBookMarked
                              ? CupertinoIcons.bookmark_fill
                              : CupertinoIcons.bookmark,
                          iconColor: _isBookMarked
                              ? theme.colorScheme.onPrimaryContainer
                              : Colors.white,
                          label: formatCount(_bookMarkCount),
                          onTap: _toggleBookMark,
                        ),
                  const SizedBox(height: 18),
                  // repost
                  _isRepostSubmitting
                      ? const SizedBox(
                          width: 30,
                          height: 46,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : ReelAction(
                          icon: _isReposted
                              ? CupertinoIcons.arrow_2_squarepath
                              : CupertinoIcons.repeat,
                          iconColor: _isReposted
                              ? theme.colorScheme.onSecondary
                              : Colors.white,
                          label: formatCount(_repostCount),
                          onTap: _toggleRepost,
                        ),
                  const SizedBox(height: 18),

                  GestureDetector(
                    onTap: widget.onTapProfile,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: ClipOval(
                        child: widget.avatarUrl.trim().isNotEmpty
                            ? UserAvatar(source: widget.avatarUrl, radius: 20)
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
    );
  }
}

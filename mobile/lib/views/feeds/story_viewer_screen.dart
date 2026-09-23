import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/story_model.dart';
import 'package:social_app/views/feeds/widgets/reel_media_shimmer.dart';
import 'package:social_app/views/feeds/widgets/story_progress_bar.dart';
import 'package:social_app/views/feeds/widgets/video_background.dart';
import 'package:video_player/video_player.dart';

const _imageDuration = Duration(seconds: 5);
const _pageTransition = Duration(milliseconds: 250);

/// Full-screen story viewer — a [PageView] across authors (swipe
/// left/right), each page auto-advancing through that author's stories
/// (tap left third for previous, right two-thirds for next) like
/// Instagram/WhatsApp status.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.onStoryViewed,
  });

  final List<StoryGroupModel> groups;
  final int initialGroupIndex;
  final void Function(String storyId)? onStoryViewed;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late final PageController _pageController;
  late int _groupIndex;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex;
    _pageController = PageController(initialPage: _groupIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() => context.pop();

  void _goToNextGroup() {
    if (_groupIndex < widget.groups.length - 1) {
      _pageController.nextPage(duration: _pageTransition, curve: Curves.easeOut);
    } else {
      _close();
    }
  }

  void _goToPreviousGroup() {
    if (_groupIndex > 0) {
      _pageController.previousPage(duration: _pageTransition, curve: Curves.easeOut);
    } else {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.groups.length,
        onPageChanged: (i) => setState(() => _groupIndex = i),
        itemBuilder: (context, i) {
          return _StoryGroupPage(
            key: ValueKey(widget.groups[i].user.id),
            group: widget.groups[i],
            isActive: i == _groupIndex,
            onClose: _close,
            onFinished: _goToNextGroup,
            onPreviousGroup: _goToPreviousGroup,
            onStoryViewed: widget.onStoryViewed,
          );
        },
      ),
    );
  }
}

class _StoryGroupPage extends StatefulWidget {
  const _StoryGroupPage({
    super.key,
    required this.group,
    required this.isActive,
    required this.onClose,
    required this.onFinished,
    required this.onPreviousGroup,
    this.onStoryViewed,
  });

  final StoryGroupModel group;
  final bool isActive;
  final VoidCallback onClose;
  final VoidCallback onFinished;
  final VoidCallback onPreviousGroup;
  final void Function(String storyId)? onStoryViewed;

  @override
  State<_StoryGroupPage> createState() => _StoryGroupPageState();
}

class _StoryGroupPageState extends State<_StoryGroupPage>
    with TickerProviderStateMixin {
  static const _videoLoadTimeout = Duration(seconds: 12);
  static const _errorDisplayDuration = Duration(seconds: 2);

  late final AnimationController _controller;
  int _index = 0;
  VideoPlayerController? _videoController;
  bool _hasError = false;

  // 0.0 = identity, 1.0 = fully dismissed.
  late final AnimationController _dismissController;
  double _dragExtent = 0.0;
  static const _dismissMaxDrag = 300.0;
  static const _dismissDistanceThreshold = 140.0;
  static const _dismissVelocityThreshold = 250.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _imageDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _goNext();
      });
    _dismissController = AnimationController(vsync: this, value: 0.0);
    if (widget.isActive) _loadStory(_index);
  }

  @override
  void didUpdateWidget(covariant _StoryGroupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (_videoController == null && !_controller.isAnimating) {
        _loadStory(_index);
      } else {
        _resume();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      _pause();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dismissController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadStory(int index) async {
    final story = widget.group.stories[index];
    widget.onStoryViewed?.call(story.id);

    _controller.stop();
    _controller.reset();
    _videoController?.dispose();
    _videoController = null;
    if (_hasError) setState(() => _hasError = false);

    if (story.mediaType == MediaType.video) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
      try {
        await controller.initialize().timeout(_videoLoadTimeout);
      } catch (_) {
        controller.dispose();
        if (mounted) _handleLoadError();
        return;
      }
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setLooping(false);
      setState(() {
        _videoController = controller;
        _controller.duration = controller.value.duration;
      });
    } else {
      setState(() => _controller.duration = _imageDuration);
    }

    if (widget.isActive) {
      _videoController?.play();
      _controller.forward(from: 0);
    }
  }

  // Surface the failure briefly instead of jump-cutting to the next story:
  // the progress bar visibly fills over `_errorDisplayDuration` so the skip
  // reads as "this one failed to load" rather than nothing happening.
  void _handleLoadError() {
    setState(() {
      _hasError = true;
      _controller.duration = _errorDisplayDuration;
    });
    if (widget.isActive) _controller.forward(from: 0);
  }

  void _pause() {
    _controller.stop();
    _videoController?.pause();
  }

  void _resume() {
    if (!widget.isActive) return;
    _videoController?.play();
    _controller.forward();
  }

  void _goNext() {
    if (_index < widget.group.stories.length - 1) {
      setState(() => _index++);
      _loadStory(_index);
    } else {
      widget.onFinished();
    }
  }

  void _goPrevious() {
    if (_index > 0) {
      setState(() => _index--);
      _loadStory(_index);
    } else {
      widget.onPreviousGroup();
    }
  }

  void _onDismissDragStart(DragStartDetails details) {
    if (_dismissController.isAnimating) return;
    _pause();
  }

  void _onDismissDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta;
    if (delta == null) return;
    _dragExtent = (_dragExtent + delta).clamp(0.0, _dismissMaxDrag);
    _dismissController.value = _dragExtent / _dismissMaxDrag;
  }

  void _onDismissDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss =
        _dragExtent > _dismissDistanceThreshold ||
        velocity > _dismissVelocityThreshold;
    shouldDismiss ? _commitDismiss() : _cancelDismiss();
  }

  void _commitDismiss() {
    _dismissController
        .animateTo(1.0, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
        .whenComplete(() {
          if (mounted) widget.onClose();
        });
  }

  void _cancelDismiss() {
    _dismissController
        .animateTo(
          0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          _dragExtent = 0.0;
          if (mounted) _resume();
        });
  }

  Widget _buildMedia(StoryModel story) {
    if (_hasError) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 40),
              SizedBox(height: 12),
              Text(
                "Couldn't load story\nCheck your connection",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    if (story.mediaType == MediaType.video) {
      final controller = _videoController;
      return controller != null && controller.value.isInitialized
          ? VideoBackground(controller: controller)
          : const ReelMediaShimmer();
    }
    return Image.network(
      story.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const ReelMediaShimmer(),
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.group.stories[_index];

    return GestureDetector(
      onTapUp: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < width / 3) {
          _goPrevious();
        } else {
          _goNext();
        }
      },
      onLongPressStart: (_) => _pause(),
      onLongPressEnd: (_) => _resume(),
      onVerticalDragStart: _onDismissDragStart,
      onVerticalDragUpdate: _onDismissDragUpdate,
      onVerticalDragEnd: _onDismissDragEnd,
      child: AnimatedBuilder(
        animation: _dismissController,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(story),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black45, Colors.transparent],
                  stops: [0.0, 0.25],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => StoryProgressBar(
                        itemCount: widget.group.stories.length,
                        currentIndex: _index,
                        progress: _controller.value,
                      ),
                    ),
                    _StoryHeader(
                      group: widget.group,
                      createdAt: story.createdAt,
                      onClose: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
            if (story.caption.trim().isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Text(
                  story.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                  ),
                ),
              ),
          ],
        ),
        builder: (context, child) {
          final t = _dismissController.value;
          return Opacity(
            opacity: 1.0 - t,
            child: Transform.translate(
              offset: Offset(0, t * _dismissMaxDrag),
              child: Transform.scale(
                scale: 1.0 - (t * 0.15),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({
    required this.group,
    required this.createdAt,
    required this.onClose,
  });

  final StoryGroupModel group;
  final DateTime createdAt;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final user = group.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          UserAvatar(
            source: user.image.trim().isNotEmpty ? user.image : user.getInitials,
            radius: 16,
            textColor: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo(createdAt),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

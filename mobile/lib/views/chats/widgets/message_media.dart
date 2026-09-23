import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

const _mediaWidth = 220.0;

/// Tappable image thumbnail that opens a zoomable full-screen view.
class ChatImageContent extends StatelessWidget {
  const ChatImageContent({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
                ),
              ),
              const Positioned(top: 40, right: 12, child: CloseButton(color: Colors.white)),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          width: _mediaWidth,
          fit: BoxFit.cover,
          placeholder: (_, _) => const SizedBox(
            width: _mediaWidth,
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (_, _, _) => const SizedBox(
            width: _mediaWidth,
            height: 160,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}

/// Video thumbnail (Cloudinary serves a frame when the extension is swapped
/// for .jpg) with a play button; tapping opens [ChatVideoPlayerScreen].
class ChatVideoContent extends StatelessWidget {
  const ChatVideoContent({super.key, required this.url});

  final String url;

  String get _thumbnailUrl {
    final dot = url.lastIndexOf('.');
    return dot == -1 ? url : '${url.substring(0, dot)}.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ChatVideoPlayerScreen(url: url)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: _thumbnailUrl,
              width: _mediaWidth,
              height: 160,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(width: _mediaWidth, height: 160, color: Colors.black54),
              errorWidget: (_, _, _) => Container(width: _mediaWidth, height: 160, color: Colors.black54),
            ),
            const CircleAvatar(
              backgroundColor: Colors.black54,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatVideoPlayerScreen extends StatefulWidget {
  const ChatVideoPlayerScreen({super.key, required this.url});

  final String url;

  @override
  State<ChatVideoPlayerScreen> createState() => _ChatVideoPlayerScreenState();
}

class _ChatVideoPlayerScreenState extends State<ChatVideoPlayerScreen> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: _controller.value.isInitialized
            ? GestureDetector(
                onTap: () => setState(
                  () => _controller.value.isPlaying ? _controller.pause() : _controller.play(),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (!_controller.value.isPlaying)
                      const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 72),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// Inline play/pause + progress for a voice note. The audio source is only
/// loaded on first play, so a long thread doesn't open a player per bubble.
class ChatVoiceNoteContent extends StatefulWidget {
  const ChatVoiceNoteContent({
    super.key,
    required this.url,
    required this.durationSeconds,
    required this.foreground,
  });

  final String url;
  final int? durationSeconds;
  final Color foreground;

  @override
  State<ChatVoiceNoteContent> createState() => _ChatVoiceNoteContentState();
}

class _ChatVoiceNoteContentState extends State<ChatVoiceNoteContent> {
  final _player = AudioPlayer();
  bool _loaded = false;
  bool _loading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (!_loaded) {
      setState(() => _loading = true);
      try {
        await _player.setUrl(widget.url);
        _loaded = true;
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = Duration(seconds: widget.durationSeconds ?? 0);

    return SizedBox(
      width: _mediaWidth,
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              final done = snapshot.data?.processingState == ProcessingState.completed;
              return IconButton(
                onPressed: _loading ? null : _toggle,
                icon: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: widget.foreground),
                      )
                    : Icon(
                        playing && !done ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: widget.foreground,
                      ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final progress = total.inMilliseconds == 0
                    ? 0.0
                    : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      color: widget.foreground,
                      backgroundColor: widget.foreground.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _format(_player.playing || position > Duration.zero ? position : total),
                      style: TextStyle(fontSize: 11, color: widget.foreground),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

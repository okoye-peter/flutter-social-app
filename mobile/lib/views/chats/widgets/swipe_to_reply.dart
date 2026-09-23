import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drag a message to the right to reply to it: the bubble follows the
/// finger (up to [_maxDrag]), a reply icon fades in behind it, and letting
/// go past [_trigger] fires [onReply]. It then springs back.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.onReply, required this.child});

  final VoidCallback onReply;
  final Widget child;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  static const _maxDrag = 72.0;
  static const _trigger = 52.0;

  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  double _dx = 0;
  // Offset the spring-back animation started from.
  double _releasedAt = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _dx = _releasedAt * (1 - _controller.value)));
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_controller.isAnimating) _controller.stop();
    setState(() => _dx = (_dx + details.delta.dx).clamp(0.0, _maxDrag));
    final armed = _dx >= _trigger;
    if (armed && !_armed) HapticFeedback.selectionClick();
    _armed = armed;
  }

  void _onEnd(DragEndDetails _) {
    if (_armed) widget.onReply();
    _armed = false;
    _releasedAt = _dx;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        // passthrough, not the default loose fit: the child must keep the
        // row's full width, or a right-aligned (own) message collapses to
        // its content width and ends up on the left.
        fit: StackFit.passthrough,
        children: [
          if (_dx > 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * progress,
                      child: Icon(
                        Icons.reply_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

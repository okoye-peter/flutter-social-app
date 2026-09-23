import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/group_chat_args.dart';
import 'package:social_app/models/message_model.dart';
import 'package:social_app/models/pending_attachment.dart';
import 'package:social_app/services/active_chat_tracker.dart';
import 'package:social_app/services/socket_service.dart';
import 'package:social_app/viewmodels/direct_messages/direct_message_bloc.dart';
import 'package:social_app/viewmodels/group_details/group_details_bloc.dart';
import 'package:social_app/views/chats/widgets/chat_message_input_bar.dart';
import 'package:social_app/views/chats/widgets/message_bubble.dart';
import 'package:social_app/views/chats/widgets/pending_message_bubble.dart';
import 'package:social_app/views/groups/widgets/group_avatar.dart';

// Stable per-sender name colours, so each person in a busy group is easy
// to tell apart at a glance.
const _senderColors = [
  Color(0xFF0793F1),
  Color(0xFFE5484D),
  Color(0xFF30A46C),
  Color(0xFFF76B15),
  Color(0xFF8E4EC6),
  Color(0xFF12A594),
  Color(0xFFD6409F),
  Color(0xFF3E63DD),
];

/// A group's message thread. Messages, sending, attachments and voice notes
/// reuse [DirectMessageBloc] (it works for any conversation id — the
/// "direct" part only matters when creating a brand-new 1:1 chat, which
/// never happens here). [GroupDetailsBloc] supplies member names for
/// sender labels and typing, and is handed to the info screen so edits
/// there show up in this header straight away.
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key, required this.args});

  final GroupChatArgs args;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  final _imagePicker = ImagePicker();
  late final DirectMessageBloc _messages;
  late final GroupDetailsBloc _details;
  bool _hasText = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Typing indicator — same protocol as the 1:1 ChatScreen, but several
  // people can be typing at once, each with their own expiry in case their
  // `typing:stop` is lost.
  static const _typingIdle = Duration(seconds: 3);
  static const _typingResend = Duration(seconds: 2);
  static const _typingExpire = Duration(seconds: 5);
  StreamSubscription<SocketEvent>? _typingSub;
  Timer? _typingIdleTimer;
  DateTime? _lastTypingEmit;
  final Map<String, Timer> _typers = {};

  // The message being replied to, shown above the input until sent/cancelled.
  MessageModel? _replyingTo;
  final _inputFocus = FocusNode();

  String get _conversationId => widget.args.conversationId;
  String? get _myId => getIt<UserCache>().current?.id;

  @override
  void initState() {
    super.initState();
    ActiveChatTracker.conversationId = _conversationId;
    _messages = DirectMessageBloc(otherUserId: '', conversationId: _conversationId)
      ..add(const LoadDirectMessagesEvent());
    _details = GroupDetailsBloc(conversationId: _conversationId)..add(const GroupDetailsLoadEvent());
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
      _onInputChanged(hasText);
    });
    _scrollController.addListener(_onScroll);
    _typingSub = getIt<SocketService>().events
        .where((e) => e.name == 'typing:update')
        .listen(_onTypingUpdate);
  }

  // Reversed list: the end of the scroll extent is the oldest message.
  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 300) {
      return;
    }
    final state = _messages.state;
    if (state is DirectMessageLoadedState && state.hasMore && !state.isLoadingMore) {
      _messages.add(const LoadMoreDirectMessagesEvent());
    }
  }

  void _onInputChanged(bool hasText) {
    if (!hasText) {
      _stopTyping();
      return;
    }
    final now = DateTime.now();
    final last = _lastTypingEmit;
    if (last == null || now.difference(last) >= _typingResend) {
      _lastTypingEmit = now;
      getIt<SocketService>().emit('typing:start', {'conversationId': _conversationId});
    }
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(_typingIdle, _stopTyping);
  }

  void _stopTyping() {
    _typingIdleTimer?.cancel();
    if (_lastTypingEmit == null) return;
    _lastTypingEmit = null;
    getIt<SocketService>().emit('typing:stop', {'conversationId': _conversationId});
  }

  void _onTypingUpdate(SocketEvent event) {
    final data = event.data;
    final userId = data['userId'] as String?;
    if (data['conversationId'] != _conversationId || userId == null || userId == _myId) return;
    _typers.remove(userId)?.cancel();
    if (data['isTyping'] == true) {
      _typers[userId] = Timer(_typingExpire, () {
        if (mounted) setState(() => _typers.remove(userId));
      });
    }
    if (mounted) setState(() {});
  }

  String? _typingLabel(GroupDetailsState details) {
    if (_typers.isEmpty) return null;
    final names = _typers.keys
        .map((id) => details.memberById(id)?.user.name.split(' ').first)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return 'Someone is typing…';
    if (names.length == 1) return '${names[0]} is typing…';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing…';
    return 'Several people are typing…';
  }

  void _startReply(MessageModel message) {
    setState(() => _replyingTo = message);
    _inputFocus.requestFocus();
  }

  /// The id to send as replyToId — and clears the reply, since it applies
  /// to exactly one outgoing message.
  String? _takeReplyId() {
    final id = _replyingTo?.id;
    if (id != null) setState(() => _replyingTo = null);
    return id;
  }

  /// A sender's display name: "You", their current member name, the name
  /// the backend sent with the message, or a placeholder for ex-members.
  String _nameFor(GroupDetailsState details, String? userId, {String? fallback, String you = 'You'}) {
    if (userId != null && userId == _myId) return you;
    return details.memberById(userId)?.user.name ?? fallback ?? 'Former member';
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _messages.add(SendTextMessageEvent(content: text, replyToId: _takeReplyId()));
    _inputController.clear();
    _stopTyping();
  }

  Future<void> _pickAttachment(MessageType type) async {
    final picked = type == MessageType.video
        ? await _imagePicker.pickVideo(source: ImageSource.gallery)
        : await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    _messages.add(
      SendAttachmentMessageEvent(
        attachment: PendingAttachment(bytes: bytes, fileName: picked.name, messageType: type),
        replyToId: _takeReplyId(),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    // wav for the same Cloudinary format-detection reason as ChatScreen.
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingDuration += const Duration(seconds: 1));
    });
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _stopRecording({required bool discard}) async {
    final path = await _recorder.stop();
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final duration = _recordingDuration;
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
    if (discard || path == null) return;

    final bytes = await File(path).readAsBytes();
    _messages.add(
      SendAttachmentMessageEvent(
        attachment: PendingAttachment(
          bytes: bytes,
          fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
          messageType: MessageType.voiceNote,
          durationSeconds: duration.inSeconds,
        ),
        replyToId: _takeReplyId(),
      ),
    );
  }

  void _openInfo() => context.push(AppRoutes.groupInfo, extra: _details);

  @override
  void dispose() {
    if (ActiveChatTracker.conversationId == _conversationId) {
      ActiveChatTracker.conversationId = null;
    }
    _stopTyping();
    _typingSub?.cancel();
    for (final t in _typers.values) {
      t.cancel();
    }
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _messages.close();
    _details.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocListener<GroupDetailsBloc, GroupDetailsState>(
      bloc: _details,
      listenWhen: (previous, current) => !previous.exited && current.exited,
      listener: (context, state) {
        // Left or removed — also closes the info screen if it's open.
        if (state.notice != null) AppToast.show(state.notice!);
        context.go(AppRoutes.groups);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: BlocBuilder<GroupDetailsBloc, GroupDetailsState>(
            bloc: _details,
            builder: (context, details) {
              final group = details.conversation;
              final typing = _typingLabel(details);
              final memberCount = group?.members.length;
              return InkWell(
                onTap: _openInfo,
                child: Row(
                  children: [
                    GroupAvatar(image: group?.image ?? widget.args.image, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group?.name ?? widget.args.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            typing ??
                                (memberCount == null
                                    ? 'Tap for group info'
                                    : '$memberCount member${memberCount == 1 ? '' : 's'} · tap for info'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: typing != null ? FontStyle.italic : FontStyle.normal,
                              color: typing != null ? Colors.green : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Group info',
              onPressed: _openInfo,
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                // Rebuilds on member changes too, so sender names resolve
                // once the member list arrives.
                child: BlocBuilder<GroupDetailsBloc, GroupDetailsState>(
                  bloc: _details,
                  buildWhen: (p, c) => p.conversation != c.conversation,
                  builder: (context, details) => BlocBuilder<DirectMessageBloc, DirectMessageState>(
                    bloc: _messages,
                    builder: (context, state) => _buildThread(context, state, details),
                  ),
                ),
              ),
              BlocBuilder<GroupDetailsBloc, GroupDetailsState>(
                bloc: _details,
                buildWhen: (p, c) => p.conversation != c.conversation,
                builder: (context, details) {
                  final replyingTo = _replyingTo;
                  return ChatMessageInputBar(
                    controller: _inputController,
                    hasText: _hasText,
                    onSendText: _send,
                    onPickAttachment: _pickAttachment,
                    isRecording: _isRecording,
                    recordingDuration: _recordingDuration,
                    onStartRecording: _startRecording,
                    onStopRecording: _stopRecording,
                    focusNode: _inputFocus,
                    replyingToName: replyingTo == null
                        ? null
                        : _nameFor(details, replyingTo.senderId, fallback: replyingTo.senderName, you: 'yourself'),
                    replyingToSummary:
                        replyingTo == null ? null : MessageReplyPreview.fromMessage(replyingTo).summary,
                    onCancelReply: () => setState(() => _replyingTo = null),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThread(BuildContext context, DirectMessageState state, GroupDetailsState details) {
    final colorScheme = Theme.of(context).colorScheme;
    if (state is DirectMessageErrorState) {
      return Center(child: Text(state.message));
    }
    if (state is! DirectMessageLoadedState) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingEntries = state.pendingSends.entries.toList();
    final totalCount = pendingEntries.length + state.items.length + (state.isLoadingMore ? 1 : 0);
    if (pendingEntries.isEmpty && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GroupAvatar(image: details.conversation?.image ?? widget.args.image, radius: 36),
              const SizedBox(height: 14),
              Text(
                details.conversation?.name ?? widget.args.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'No messages yet. Say hi to the group 👋',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < pendingEntries.length) {
          final entry = pendingEntries[pendingEntries.length - 1 - index];
          return PendingMessageBubble(
            pending: entry.value,
            onRetry: () => _messages.add(RetrySendMessageEvent(localId: entry.key)),
            onCancel: () => _messages.add(CancelSendMessageEvent(localId: entry.key)),
          );
        }
        final itemIndex = index - pendingEntries.length;
        if (itemIndex >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        // Newest-first, so the message shown just above this one is at
        // itemIndex + 1.
        final message = state.items[itemIndex];
        if (message.type == MessageType.system) return _SystemMessage(message: message);

        final isMine = message.senderId == _myId;
        final replyTo = message.replyTo;
        final bubble = MessageBubble(
          message: message,
          isMine: isMine,
          onReply: () => _startReply(message),
          onReact: (emoji) => _messages.add(ToggleReactionEvent(messageId: message.id, emoji: emoji)),
          replySenderName: replyTo == null
              ? null
              : _nameFor(details, replyTo.senderId, fallback: replyTo.senderName),
        );
        if (isMine) return bubble;

        final older = itemIndex + 1 < state.items.length ? state.items[itemIndex + 1] : null;
        final startsRun = older == null || older.senderId != message.senderId || older.type == MessageType.system;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (startsRun)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 8, bottom: 2),
                child: Text(
                  _nameFor(details, message.senderId, fallback: message.senderName),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _senderColors[(message.senderId ?? '').hashCode.abs() % _senderColors.length],
                  ),
                ),
              ),
            bubble,
          ],
        );
      },
    );
  }
}

/// "Alice joined the group" etc. — centered, not a chat bubble.
class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

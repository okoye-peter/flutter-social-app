import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/pending_attachment.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/viewmodels/call/call_bloc.dart';
import 'package:social_app/viewmodels/direct_messages/direct_message_bloc.dart';
import 'package:social_app/views/chats/widgets/chat_empty_thread.dart';
import 'package:social_app/views/chats/widgets/chat_message_input_bar.dart';
import 'package:social_app/views/chats/widgets/message_bubble.dart';
import 'package:social_app/views/chats/widgets/pending_message_bubble.dart';

/// A single conversation thread, backed by [DirectMessageBloc]. When
/// [conversationId] is null (a brand-new chat with no thread yet), the
/// bloc creates the conversation lazily on the first message sent.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.otherUser,
    this.conversationId,
  });

  final String? conversationId;
  final UserModel otherUser;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  final _imagePicker = ImagePicker();
  late final DirectMessageBloc _bloc;
  bool _hasText = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _bloc = DirectMessageBloc(
      otherUserId: widget.otherUser.id,
      conversationId: widget.conversationId,
    )..add(const LoadDirectMessagesEvent());
    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _bloc.add(SendTextMessageEvent(content: text));
    _inputController.clear();
  }

  void _startCall(CallType type) {
    final conversationId = widget.conversationId;
    if (conversationId == null) return;
    getIt<CallBloc>().add(
      StartOutgoingCallEvent(
        conversationId: conversationId,
        otherUser: widget.otherUser,
        type: type,
      ),
    );
  }

  Future<void> _pickAttachment(MessageType type) async {
    final picked = type == MessageType.video
        ? await _imagePicker.pickVideo(source: ImageSource.gallery)
        : await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    _bloc.add(
      SendAttachmentMessageEvent(
        attachment: PendingAttachment(
          bytes: bytes,
          fileName: picked.name,
          messageType: type,
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    // wav, not the default aacLc: aacLc's MPEG-4 container is
    // byte-identical to an mp4 video container, so Cloudinary reports it
    // as format 'mp4' regardless of the .m4a filename — which collides
    // with VIDEO's allowed formats and gets rejected. wav is the one
    // encoder record produces identically (and unambiguously) on every
    // platform.
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
    _bloc.add(
      SendAttachmentMessageEvent(
        attachment: PendingAttachment(
          bytes: bytes,
          fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
          messageType: MessageType.voiceNote,
          durationSeconds: duration.inSeconds,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = widget.otherUser;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              UserAvatar(
                source: user.image.trim().isNotEmpty
                    ? user.image
                    : (user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                radius: 18,
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      user.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: user.isOnline ? Colors.green : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: widget.conversationId == null
                  ? null // a call needs an existing conversation — send a
                  // message first in a brand-new chat
                  : () => _startCall(CallType.voice),
              icon: const Icon(Icons.call_outlined),
            ),
            IconButton(
              onPressed: widget.conversationId == null ? null : () => _startCall(CallType.video),
              icon: const Icon(Icons.videocam_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: BlocBuilder<DirectMessageBloc, DirectMessageState>(
                  builder: (context, state) {
                    if (state is DirectMessageErrorState) {
                      return Center(child: Text(state.message));
                    }
                    if (state is! DirectMessageLoadedState) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final pendingEntries = state.pendingSends.entries.toList();
                    final totalCount = pendingEntries.length + state.items.length;
                    if (totalCount == 0) {
                      return ChatEmptyThread(user: user);
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: totalCount,
                      itemBuilder: (context, index) {
                        if (index < pendingEntries.length) {
                          // Most-recently-added pending send renders
                          // nearest the input bar (index 0 in a reversed
                          // list), oldest pending send just above the
                          // newest confirmed message.
                          final entry = pendingEntries[pendingEntries.length - 1 - index];
                          return PendingMessageBubble(
                            pending: entry.value,
                            onRetry: () =>
                                _bloc.add(RetrySendMessageEvent(localId: entry.key)),
                            onCancel: () =>
                                _bloc.add(CancelSendMessageEvent(localId: entry.key)),
                          );
                        }
                        // state.items is already newest-first (matches the
                        // backend's ordering), so no index inversion needed.
                        final message = state.items[index - pendingEntries.length];
                        final isMine = message.senderId == getIt<UserCache>().current?.id;
                        return MessageBubble(message: message, isMine: isMine);
                      },
                    );
                  },
                ),
              ),
              ChatMessageInputBar(
                controller: _inputController,
                hasText: _hasText,
                onSendText: _send,
                onPickAttachment: _pickAttachment,
                isRecording: _isRecording,
                recordingDuration: _recordingDuration,
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

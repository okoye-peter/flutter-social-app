part of 'direct_message_bloc.dart';

sealed class DirectMessageEvent extends Equatable {
  const DirectMessageEvent();

  @override
  List<Object?> get props => [];
}

final class LoadDirectMessagesEvent extends DirectMessageEvent {
  const LoadDirectMessagesEvent();
}

// No cursor/query fields — the bloc reads its own current cursor from
// state rather than trusting the caller to supply a matching one.
final class LoadMoreDirectMessagesEvent extends DirectMessageEvent {
  const LoadMoreDirectMessagesEvent();
}

final class SendTextMessageEvent extends DirectMessageEvent {
  const SendTextMessageEvent({
    required this.content,
    this.replyToId,
    this.mentionedUserIds,
  });

  final String content;
  final String? replyToId;
  final List<String>? mentionedUserIds;

  @override
  List<Object?> get props => [content, replyToId, mentionedUserIds];
}

final class SendAttachmentMessageEvent extends DirectMessageEvent {
  const SendAttachmentMessageEvent({
    required this.attachment,
    this.content,
    this.replyToId,
  });

  final PendingAttachment attachment;

  /// Optional caption.
  final String? content;
  final String? replyToId;

  @override
  List<Object?> get props => [attachment, content, replyToId];
}

final class RetrySendMessageEvent extends DirectMessageEvent {
  const RetrySendMessageEvent({required this.localId});

  final String localId;

  @override
  List<Object?> get props => [localId];
}

final class CancelSendMessageEvent extends DirectMessageEvent {
  const CancelSendMessageEvent({required this.localId});

  final String localId;

  @override
  List<Object?> get props => [localId];
}

/// A `message:new` socket broadcast for this conversation.
final class MessageReceivedEvent extends DirectMessageEvent {
  const MessageReceivedEvent(this.message);

  final MessageModel message;

  @override
  List<Object?> get props => [message];
}

/// The caller tapped an emoji on a message (from the long-press menu or an
/// existing reaction chip).
final class ToggleReactionEvent extends DirectMessageEvent {
  const ToggleReactionEvent({required this.messageId, required this.emoji});

  final String messageId;
  final String emoji;

  @override
  List<Object?> get props => [messageId, emoji];
}

/// A `message:reaction` / `message:reaction-removed` socket broadcast.
/// [emoji] is null when the reaction was removed.
final class ReactionChangedEvent extends DirectMessageEvent {
  const ReactionChangedEvent({required this.messageId, required this.userId, this.emoji});

  final String messageId;
  final String userId;
  final String? emoji;

  @override
  List<Object?> get props => [messageId, userId, emoji];
}

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

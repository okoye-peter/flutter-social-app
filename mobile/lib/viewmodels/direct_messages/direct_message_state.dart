part of 'direct_message_bloc.dart';

enum SendPhase { uploading, sendingMessage, failed }

class PendingSend extends Equatable {
  const PendingSend({
    required this.phase,
    this.progress = 0,
    this.attachment,
    this.content,
    this.replyToId,
    this.errorMessage,
  });

  final SendPhase phase;

  /// 0.0-1.0, meaningful only while phase == uploading.
  final double progress;

  /// Null for a text-only pending send.
  final PendingAttachment? attachment;
  final String? content;
  final String? replyToId;
  final String? errorMessage;

  PendingSend copyWith({SendPhase? phase, double? progress, String? errorMessage}) {
    return PendingSend(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      attachment: attachment,
      content: content,
      replyToId: replyToId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    progress,
    attachment,
    content,
    replyToId,
    errorMessage,
  ];
}

sealed class DirectMessageState extends Equatable {
  const DirectMessageState();

  @override
  List<Object?> get props => [];
}

final class DirectMessageInitialState extends DirectMessageState {}

final class DirectMessageLoadingState extends DirectMessageState {}

final class DirectMessageErrorState extends DirectMessageState {
  const DirectMessageErrorState({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

final class DirectMessageLoadedState extends DirectMessageState {
  const DirectMessageLoadedState({
    required this.items,
    this.cursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.pendingSends = const {},
  });

  /// Newest-first, matching GET /conversations/:id/messages ordering.
  final List<MessageModel> items;
  final String? cursor;
  final bool hasMore;
  final bool isLoadingMore;

  /// localId -> in-flight send, most-recently-added rendered first ahead
  /// of [items].
  final Map<String, PendingSend> pendingSends;

  // Sentinel so copyWith can clear cursor back to null (e.g. once the last
  // page is reached) instead of a plain `?? current` silently keeping it.
  static const _unset = Object();

  DirectMessageLoadedState copyWith({
    List<MessageModel>? items,
    Object? cursor = _unset,
    bool? hasMore,
    bool? isLoadingMore,
    Map<String, PendingSend>? pendingSends,
  }) {
    return DirectMessageLoadedState(
      items: items ?? this.items,
      cursor: identical(cursor, _unset) ? this.cursor : cursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pendingSends: pendingSends ?? this.pendingSends,
    );
  }

  @override
  List<Object?> get props => [
    items,
    cursor,
    hasMore,
    isLoadingMore,
    pendingSends,
  ];
}

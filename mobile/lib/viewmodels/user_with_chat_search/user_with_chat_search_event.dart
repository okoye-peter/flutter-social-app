part of 'user_with_chat_search_bloc.dart';

sealed class UserWithChatSearchEvent extends Equatable {
  const UserWithChatSearchEvent();

  @override
  List<Object?> get props => [];
}

final class UserWithChatSearchQueryChangedEvent extends UserWithChatSearchEvent {
  const UserWithChatSearchQueryChangedEvent({this.query = ''});

  final String query;

  @override
  List<Object?> get props => [query];
}

final class UserWithChatSearchLoadMoreEvent extends UserWithChatSearchEvent {
  const UserWithChatSearchLoadMoreEvent({ required this.cursor, this.query = '' });

  final String query, cursor;

  @override
  List<Object?> get props => [query, cursor];
}

/// A `message:new` socket broadcast — bumps the matching row to the top.
final class UserWithChatSearchMessageReceivedEvent extends UserWithChatSearchEvent {
  const UserWithChatSearchMessageReceivedEvent(this.message);

  final MessageModel message;

  @override
  List<Object?> get props => [message];
}

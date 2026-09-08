part of 'user_without_chat_search_bloc.dart';

sealed class UserWithoutChatSearchEvent extends Equatable {
  const UserWithoutChatSearchEvent();

  @override
  List<Object?> get props => [];
}

final class UserWithoutChatSearchQueryChangedEvent extends UserWithoutChatSearchEvent {
  const UserWithoutChatSearchQueryChangedEvent({this.query = ''});

  final String query;

  @override
  List<Object?> get props => [query];
}

final class UserWithoutChatSearchLoadMoreEvent extends UserWithoutChatSearchEvent {
  const UserWithoutChatSearchLoadMoreEvent({ required this.cursor, this.query = '' });

  final String query, cursor;

  @override
  List<Object?> get props => [query, cursor];
}
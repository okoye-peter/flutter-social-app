part of 'my_groups_bloc.dart';

sealed class MyGroupsEvent extends Equatable {
  const MyGroupsEvent();

  @override
  List<Object?> get props => [];
}

/// (Re)loads the first page. [silent] keeps the current list on screen
/// instead of flashing a spinner — for socket-driven background refreshes.
final class MyGroupsLoadEvent extends MyGroupsEvent {
  const MyGroupsLoadEvent({this.query = '', this.silent = false});

  final String query;
  final bool silent;

  @override
  List<Object?> get props => [query, silent];
}

final class MyGroupsLoadMoreEvent extends MyGroupsEvent {
  const MyGroupsLoadMoreEvent();
}

/// A `message:new` socket broadcast — bumps the matching group to the top.
final class MyGroupsMessageReceivedEvent extends MyGroupsEvent {
  const MyGroupsMessageReceivedEvent(this.message);

  final MessageModel message;

  @override
  List<Object?> get props => [message];
}

/// The user just came back from a group's thread, which marked it read
/// server-side — clear its badge locally instead of refetching.
final class MyGroupsMarkedReadEvent extends MyGroupsEvent {
  const MyGroupsMarkedReadEvent(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

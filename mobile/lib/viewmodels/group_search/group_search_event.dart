part of 'group_search_bloc.dart';

sealed class GroupSearchEvent extends Equatable {
  const GroupSearchEvent();
  @override
  List<Object> get props => [];
}

final class GroupSearchQueryChanged extends GroupSearchEvent {
  const GroupSearchQueryChanged(this.query);
  final String query;
  @override
  List<Object> get props => [query];
}

/// Join a PUBLIC group, or request to join a PRIVATE one.
final class GroupJoinPressed extends GroupSearchEvent {
  const GroupJoinPressed(this.group);
  final GroupModel group;
  @override
  List<Object> get props => [group];
}

/// Withdraw a still-pending join request.
final class GroupJoinCancelPressed extends GroupSearchEvent {
  const GroupJoinCancelPressed(this.group);
  final GroupModel group;
  @override
  List<Object> get props => [group];
}

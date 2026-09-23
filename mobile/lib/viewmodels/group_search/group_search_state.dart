part of 'group_search_bloc.dart';

sealed class GroupSearchState extends Equatable {
  const GroupSearchState();
  @override
  List<Object?> get props => [];
}

final class GroupSearchInitialState extends GroupSearchState {
  const GroupSearchInitialState();
}

final class GroupSearchLoadingState extends GroupSearchState {
  const GroupSearchLoadingState();
}

final class GroupSearchLoadedState extends GroupSearchState {
  const GroupSearchLoadedState({
    required this.groups,
    this.busyIds = const {},
    this.joined,
    this.notice,
    this.actionError,
  });

  final List<GroupModel> groups;
  // Groups with a join/cancel request in flight — their button shows a
  // spinner and ignores taps.
  final Set<String> busyIds;
  // One-shot side effects for the screen's listener (never carried over by
  // copyWith): a PUBLIC group just joined (open it), an info message, or a
  // failed join/cancel.
  final GroupModel? joined;
  final String? notice;
  final String? actionError;

  GroupSearchLoadedState copyWith({
    List<GroupModel>? groups,
    Set<String>? busyIds,
    GroupModel? joined,
    String? notice,
    String? actionError,
  }) {
    return GroupSearchLoadedState(
      groups: groups ?? this.groups,
      busyIds: busyIds ?? this.busyIds,
      joined: joined,
      notice: notice,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [groups, busyIds, joined, notice, actionError];
}

final class GroupSearchErrorState extends GroupSearchState {
  const GroupSearchErrorState({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}

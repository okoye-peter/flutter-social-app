part of 'group_search_bloc.dart';

sealed class GroupSearchState extends Equatable {
  const GroupSearchState();
  @override
  List<Object> get props => [];
}

final class GroupSearchInitialState extends GroupSearchState {
  const GroupSearchInitialState();
}

final class GroupSearchLoadingState extends GroupSearchState {
  const GroupSearchLoadingState();
}

final class GroupSearchLoadedState extends GroupSearchState {
  const GroupSearchLoadedState({required this.groups});
  final List<GroupModel> groups;
  @override
  List<Object> get props => [groups];
}

final class GroupSearchErrorState extends GroupSearchState {
  const GroupSearchErrorState({required this.message});
  final String message;
  @override
  List<Object> get props => [message];
}

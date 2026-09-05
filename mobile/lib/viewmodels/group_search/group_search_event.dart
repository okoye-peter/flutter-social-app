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

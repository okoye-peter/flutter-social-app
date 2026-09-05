part of 'user_search_bloc.dart';

sealed class UserSearchEvent extends Equatable {
  const UserSearchEvent();
  @override
  List<Object> get props => [];
}

final class UserSearchQueryChanged extends UserSearchEvent {
  const UserSearchQueryChanged(this.query);
  final String query;
  @override
  List<Object> get props => [query];
}

final class UserSearchFollowToggled extends UserSearchEvent {
  const UserSearchFollowToggled(this.user);
  final UserModel user;
  @override
  List<Object> get props => [user];
}

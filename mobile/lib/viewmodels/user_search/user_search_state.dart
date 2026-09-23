part of 'user_search_bloc.dart';

sealed class UserSearchState extends Equatable {
  const UserSearchState();
  @override
  List<Object> get props => [];
}

final class UserSearchInitialState extends UserSearchState {
  const UserSearchInitialState();
}

final class UserSearchLoadingState extends UserSearchState {
  const UserSearchLoadingState();
}

final class UserSearchLoadedState extends UserSearchState {
  const UserSearchLoadedState({required this.users});
  final List<UserModel> users;
  @override
  List<Object> get props => [users];
}

final class UserSearchErrorState extends UserSearchState {
  const UserSearchErrorState({required this.message});
  final String message;
  @override
  List<Object> get props => [message];
}

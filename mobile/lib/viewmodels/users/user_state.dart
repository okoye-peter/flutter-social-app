part of 'user_bloc.dart';

sealed class UserState extends Equatable {
  const UserState();

  @override
  List<Object> get props => [];
}

final class UserInitialState extends UserState {
  const UserInitialState();
}

final class UserLoadingState extends UserState {
  const UserLoadingState();
}

final class UserUpdatedState extends UserState {
  const UserUpdatedState({required this.user});

  final UserModel user;

  @override
  List<Object> get props => [user];
}

final class UserErrorState extends UserState {
  const UserErrorState({required this.message});

  final String message;

  @override
  List<Object> get props => [message];
}

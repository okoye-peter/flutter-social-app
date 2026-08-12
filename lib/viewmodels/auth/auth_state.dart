part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoadingState extends AuthState {
  const AuthLoadingState();
}

final class AuthLoadedState extends AuthState {
  const AuthLoadedState();
}

final class AuthErrorState extends AuthState {
  final String errorMessage;

  const AuthErrorState(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];
}

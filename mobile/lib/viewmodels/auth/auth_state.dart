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
  final UserModel user;

  const AuthLoadedState(this.user);

  @override
  List<Object> get props => [user];
}

final class AuthUnauthenticatedState extends AuthState {
  const AuthUnauthenticatedState();
}

final class AuthErrorState extends AuthState {
  final String errorMessage;

  const AuthErrorState(this.errorMessage);

  @override
  List<Object> get props => [errorMessage];
}

final class OtpSentState extends AuthState {
  const OtpSentState();
}

final class OtpVerifiedState extends AuthState {
  const OtpVerifiedState();
}


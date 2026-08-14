part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class RegisterEvent extends AuthEvent {
  const RegisterEvent({required this.data});

  final RegistrationModel data;

  @override
  List<Object> get props => [data];
}

class LoginEvent extends AuthEvent {
  const LoginEvent({required this.data});

  final LoginModel data;

  @override
  List<Object> get props => [data];
}

class LogoutEvent extends AuthEvent {}

class FetchAuthenticatedUserEvent extends AuthEvent {}

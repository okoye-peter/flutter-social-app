part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class RegisterEvent extends AuthEvent {
  
}

class LoginEvent extends AuthEvent {

}

class LogoutEvent extends AuthEvent {

}

class FetchAuthenticatedUserEvent extends AuthEvent {

}

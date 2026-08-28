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

/// Fired when DioClient clears local tokens after a failed refresh —
/// tokens are already gone locally, so this only updates state/navigation,
/// unlike [LogoutEvent] which also calls the server to revoke the session.
class SessionExpiredEvent extends AuthEvent {}

class SendEmailOtpEvent extends AuthEvent {
  const SendEmailOtpEvent({required this.email});

  final String email;

  @override
  List<Object> get props => [email];
}

class VerifyEmailOtpEvent extends AuthEvent {
  const VerifyEmailOtpEvent({required this.email, required this.code});

  final String email;
  final String code;

  @override
  List<Object> get props => [email, code];
}

class SendPhoneOtpEvent extends AuthEvent {
  const SendPhoneOtpEvent({required this.phoneNumber});

  final String phoneNumber;

  @override
  List<Object> get props => [phoneNumber];
}

class VerifyPhoneOtpEvent extends AuthEvent {
  const VerifyPhoneOtpEvent({required this.phoneNumber, required this.code});

  final String phoneNumber;
  final String code;

  @override
  List<Object> get props => [phoneNumber, code];
}

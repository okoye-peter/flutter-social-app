import 'package:equatable/equatable.dart';

/// Carries the data collected so far through the multi-step registration
/// flow (email -> email OTP -> phone -> phone OTP -> details) via
/// `GoRouterState.extra`.
class RegistrationDraft extends Equatable {
  const RegistrationDraft({required this.email, this.phoneNumber});

  final String email;
  final String? phoneNumber;

  RegistrationDraft copyWith({String? phoneNumber}) {
    return RegistrationDraft(
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  @override
  List<Object?> get props => [email, phoneNumber];
}

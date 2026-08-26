import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/core/widgets/auth_scaffold.dart';
import 'package:social_app/core/widgets/otp_verification_form.dart';
import 'package:social_app/models/registration_draft.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';

class PhoneVerificationScreen extends StatelessWidget {
  const PhoneVerificationScreen({super.key, required this.draft});

  final RegistrationDraft draft;

  // Guaranteed set by this point in the flow — RegisterPhoneScreen only
  // navigates here after attaching a phoneNumber to the draft.
  String get phoneNumber => draft.phoneNumber!;

  Future<String?> _onVerify(BuildContext context, String code) async {
    final state = await context.read<AuthBloc>().addAndAwait(
      VerifyPhoneOtpEvent(phoneNumber: phoneNumber, code: code),
      (s) => s is OtpVerifiedState,
    );
    if (!context.mounted) return null;
    if (state is AuthErrorState) return state.errorMessage;

    context.push(AppRoutes.registerDetails, extra: draft);
    return null;
  }

  Future<void> _onResend(BuildContext context) async {
    final state = await context.read<AuthBloc>().addAndAwait(
      SendPhoneOtpEvent(phoneNumber: phoneNumber),
      (s) => s is OtpSentState,
    );
    if (!context.mounted) return;

    if (state is AuthErrorState) {
      AppToast.error(state.errorMessage);
    } else {
      AppToast.success('Verification code resent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone = maskPhoneNumber(phoneNumber);

    return AuthScaffold(
      title: 'Verify your phone',
      subtitle:
          'Enter the 6-digit code we sent via SMS to $maskedPhone to verify your number.',
      showBackButton: true,
      child: OtpVerificationForm(
        onVerify: (code) => _onVerify(context, code),
        onResend: () => _onResend(context),
      ),
    );
  }
}

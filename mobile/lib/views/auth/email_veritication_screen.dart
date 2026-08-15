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

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key, required this.draft});

  final RegistrationDraft draft;

  Future<String?> _onVerify(BuildContext context, String code) async {
    final state = await context.read<AuthBloc>().addAndAwait(
      VerifyEmailOtpEvent(email: draft.email, code: code),
      (s) => s is OtpVerifiedState,
    );
    if (!context.mounted) return null;
    if (state is AuthErrorState) return state.errorMessage;

    context.push(AppRoutes.registerPhone, extra: draft);
    return null;
  }

  Future<void> _onResend(BuildContext context) async {
    final state = await context.read<AuthBloc>().addAndAwait(
      SendEmailOtpEvent(email: draft.email),
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
    final maskedEmail = maskEmail(draft.email);

    return AuthScaffold(
      title: 'Verify your email',
      subtitle:
          'Enter the 6-digit code we sent to $maskedEmail to verify your email address.',
      showBackButton: true,
      child: OtpVerificationForm(
        onVerify: (code) => _onVerify(context, code),
        onResend: () => _onResend(context),
      ),
    );
  }
}

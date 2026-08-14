import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/core/widgets/auth_scaffold.dart';
import 'package:social_app/core/widgets/otp_verification_form.dart';

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  Future<String?> _onVerify(BuildContext context, String code) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!context.mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email verified successfully')),
    );
    context.go(AppRoutes.feeds);
    return null;
  }

  Future<void> _onResend(BuildContext context) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification code resent')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maskedEmail = maskEmail(email);

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

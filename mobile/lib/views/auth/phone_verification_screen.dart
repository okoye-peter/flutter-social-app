import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/formatters.dart';
import 'package:social_app/core/widgets/auth_scaffold.dart';
import 'package:social_app/core/widgets/otp_verification_form.dart';

class PhoneVerificationScreen extends StatelessWidget {
  const PhoneVerificationScreen({super.key, required this.phoneNumber});

  final String phoneNumber;

  Future<String?> _onVerify(BuildContext context, String code) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!context.mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number verified successfully')),
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/validators.dart';
import 'package:social_app/core/widgets/auth_scaffold.dart';
import 'package:social_app/core/widgets/auth_submit_button.dart';
import 'package:social_app/core/widgets/auth_text_field.dart';
import 'package:social_app/core/widgets/otp_verification_form.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';

/// Second half of the forgot-password flow: collect the new password first,
/// then verify the emailed 6-digit code — by the time OtpVerificationForm's
/// onVerify fires, the new password is already captured in
/// [_passwordController], so both can be sent to the backend together in
/// one POST /auth/reset-password call.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordConfirmed = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your new password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _onContinue() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _passwordConfirmed = true);
  }

  Future<String?> _onVerifyCode(String code) async {
    final state = await context.read<AuthBloc>().addAndAwait(
      ResetPasswordEvent(
        email: widget.email,
        code: code,
        newPassword: _passwordController.text,
      ),
      (s) => s is OtpVerifiedState,
    );
    if (!mounted) return null;
    if (state is AuthErrorState) return state.errorMessage;

    AppToast.success('Password updated — log in with your new password');
    context.go(AppRoutes.login);
    return null;
  }

  Future<void> _onResendCode() async {
    final state = await context.read<AuthBloc>().addAndAwait(
      RequestPasswordResetEvent(email: widget.email),
      (s) => s is OtpSentState,
    );
    if (!mounted) return;

    if (state is AuthErrorState) {
      AppToast.error(state.errorMessage);
    } else {
      AppToast.success('Reset code resent');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: _passwordConfirmed ? 'Enter reset code' : 'Set a new password',
      subtitle: _passwordConfirmed
          ? 'Enter the 6-digit code we emailed to ${widget.email} to finish resetting your password.'
          : 'Choose a new password for your account.',
      showBackButton: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _passwordConfirmed
            ? OtpVerificationForm(
                key: const ValueKey('code'),
                onVerify: _onVerifyCode,
                onResend: _onResendCode,
              )
            : _buildPasswordForm(),
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('password'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthTextField(
            controller: _passwordController,
            label: 'New password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.next,
            validator: validatePassword,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _confirmPasswordController,
            label: 'Confirm new password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
            validator: _validateConfirmPassword,
            onFieldSubmitted: (_) => _onContinue(),
          ),
          const SizedBox(height: 24),
          AuthSubmitButton(
            label: 'Continue',
            isLoading: false,
            onPressed: _onContinue,
          ),
        ],
      ),
    );
  }
}

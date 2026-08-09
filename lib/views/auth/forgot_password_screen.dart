import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/validators.dart';
import 'package:social_app/core/widgets/auth_scaffold.dart';
import 'package:social_app/core/widgets/auth_submit_button.dart';
import 'package:social_app/core/widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _emailSent = true;
    });
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: _emailSent ? 'Check your email' : 'Forgot password?',
      subtitle: _emailSent
          ? 'We sent a password reset link to ${_emailController.text.trim()}.'
          : "Enter the email linked to your account and we'll send you a "
                "reset link.",
      showBackButton: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
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
            child: _emailSent ? _buildSuccess(colorScheme) : _buildForm(),
          ),
          const SizedBox(height: 28),
          Center(
            child: TextButton.icon(
              onPressed: _backToLogin,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Log In'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: validateEmail,
            onFieldSubmitted: (_) => _onSendResetLink(),
          ),
          const SizedBox(height: 24),
          AuthSubmitButton(
            label: 'Send Reset Link',
            isLoading: _isLoading,
            onPressed: _onSendResetLink,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ColorScheme colorScheme) {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            color: colorScheme.primary,
            size: 34,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Didn't get the email? Check your spam folder or try again.",
          style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () => setState(() => _emailSent = false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Try a different email',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

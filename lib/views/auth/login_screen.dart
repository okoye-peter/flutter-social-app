import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/validators.dart';
import 'package:social_app/core/widgets/auth_scaffold.dart';
import 'package:social_app/core/widgets/auth_submit_button.dart';
import 'package:social_app/core/widgets/auth_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go(AppRoutes.feeds);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to keep up with your community.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: validatePassword,
              onFieldSubmitted: (_) => _onLogin(),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (value) => setState(
                                () => _rememberMe = value ?? false,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Remember me',
                              style: TextStyle(fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AuthSubmitButton(
              label: 'Log In',
              isLoading: _isLoading,
              onPressed: _onLogin,
            ),
            const SizedBox(height: 28),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.register),
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

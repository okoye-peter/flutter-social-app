import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/validators.dart';
import 'package:social_app/core/widgets/auth_scaffold.dart';
import 'package:social_app/core/widgets/auth_submit_button.dart';
import 'package:social_app/core/widgets/auth_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreedToTerms = false;
  bool _isLoading = false;
  Country _selectedCountry = Country(
    phoneCode: '234',
    countryCode: 'NG',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Nigeria',
    example: 'Nigeria',
    displayName: 'Nigeria',
    displayNameNoCountryCode: 'NG',
    e164Key: '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _onRegister() async {
    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Privacy Policy'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created successfully')),
    );
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
      title: 'Create account',
      subtitle: 'Sign up to start sharing and connecting.',
      showBackButton: false,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthTextField(
              controller: _nameController,
              label: 'Full name',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: validateName,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _phoneController,
              label: 'Phone Number',
              widgetIcon: InkWell(
                onTap: () {
                  showCountryPicker(
                    context: context,
                    showPhoneCode: true,
                    onSelect: (Country country) {
                      setState(() {
                        _selectedCountry = country;
                      });
                    },
                    countryListTheme: CountryListThemeData(
                      backgroundColor: colorScheme.onSecondary,
                      textStyle: GoogleFonts.openSans(fontSize: 13, fontWeight: FontWeight.w500),
                      inputDecoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)
                        )
                      ),
                    )
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '${_selectedCountry.flagEmoji} +${_selectedCountry.phoneCode}',
                      style: const TextStyle(fontSize: 16),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: validatePhone,
            ),
            const SizedBox(height: 16),
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
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: validatePassword,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _confirmPasswordController,
              label: 'Confirm password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              validator: _validateConfirmPassword,
              onFieldSubmitted: (_) => _onRegister(),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (value) =>
                            setState(() => _agreedToTerms = value ?? false),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AuthSubmitButton(
              label: 'Create Account',
              isLoading: _isLoading,
              onPressed: _onRegister,
            ),
            const SizedBox(height: 28),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.login);
                      }
                    },
                    child: Text(
                      'Log In',
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

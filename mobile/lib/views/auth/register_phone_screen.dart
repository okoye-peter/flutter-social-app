import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/utils/validators.dart';
import 'package:social_app/core/widgets/auth_scaffold.dart';
import 'package:social_app/core/widgets/auth_submit_button.dart';
import 'package:social_app/core/widgets/auth_text_field.dart';
import 'package:social_app/models/registration_draft.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';

/// Step 3 of registration: collect and verify the phone number, once the
/// email has already been verified.
class RegisterPhoneScreen extends StatefulWidget {
  const RegisterPhoneScreen({super.key, required this.draft});

  final RegistrationDraft draft;

  @override
  State<RegisterPhoneScreen> createState() => _RegisterPhoneScreenState();
}

class _RegisterPhoneScreenState extends State<RegisterPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
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
  String? _pendingPhoneNumber;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    _pendingPhoneNumber =
        '+${_selectedCountry.phoneCode}${_phoneController.text.trim()}';
    context.read<AuthBloc>().add(
      SendPhoneOtpEvent(phoneNumber: _pendingPhoneNumber!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Add your phone number',
      subtitle: "We'll send a code to verify it's really you.",
      showBackButton: true,
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OtpSentState) {
            context.push(
              AppRoutes.phoneVerification,
              extra: widget.draft.copyWith(phoneNumber: _pendingPhoneNumber),
            );
          } else if (state is AuthErrorState) {
            AppToast.error(state.errorMessage);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoadingState;

          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          textStyle: GoogleFonts.openSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          inputDecoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: GoogleFonts.openSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
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
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: validatePhone,
                  onFieldSubmitted: (_) => _onContinue(),
                ),
                const SizedBox(height: 24),
                AuthSubmitButton(
                  label: 'Continue',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _onContinue,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

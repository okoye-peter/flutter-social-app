import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:social_app/core/widgets/auth_submit_button.dart';

const _resendCooldown = Duration(seconds: 60);
const _brandColor = Color(0xFF0793F1);

/// Shared 6-digit OTP entry used by the phone and email verification
/// screens: pin input, verify button, and a resend row with a cooldown
/// timer. The screens own what "verify" and "resend" actually mean.
class OtpVerificationForm extends StatefulWidget {
  const OtpVerificationForm({
    super.key,
    required this.onVerify,
    required this.onResend,
    this.length = 6,
  });

  /// Return an error message to show under the pin field, or null on
  /// success.
  final Future<String?> Function(String code) onVerify;
  final Future<void> Function() onResend;
  final int length;

  @override
  State<OtpVerificationForm> createState() => _OtpVerificationFormState();
}

class _OtpVerificationFormState extends State<OtpVerificationForm> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();

  Timer? _resendTimer;
  Duration _remaining = _resendCooldown;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isCodeComplete = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _remaining = _resendCooldown);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  Future<void> _onVerify([String? pin]) async {
    final code = pin ?? _pinController.text;
    if (code.length < widget.length || _isVerifying) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    final error = await widget.onVerify(code);
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _errorText = error;
    });
  }

  Future<void> _onResend() async {
    if (_remaining > Duration.zero || _isResending) return;

    setState(() {
      _isResending = true;
      _errorText = null;
    });
    await widget.onResend();
    if (!mounted) return;

    _pinController.clear();
    setState(() {
      _isResending = false;
      _isCodeComplete = false;
    });
    _startResendTimer();
    _pinFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 54,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: _brandColor, width: 1.6),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: _brandColor, width: 1.2),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: colorScheme.error, width: 1.6),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Pinput(
          length: widget.length,
          controller: _pinController,
          focusNode: _pinFocusNode,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: submittedPinTheme,
          errorPinTheme: errorPinTheme,
          errorText: _errorText,
          pinAnimationType: PinAnimationType.fade,
          showCursor: true,
          cursor: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 2,
                height: 22,
                margin: const EdgeInsets.only(bottom: 10),
                color: _brandColor,
              ),
            ],
          ),
          onChanged: (value) {
            if (_errorText != null) setState(() => _errorText = null);
            setState(() => _isCodeComplete = value.length == widget.length);
          },
          onCompleted: _onVerify,
        ),
        const SizedBox(height: 32),
        AuthSubmitButton(
          label: 'Verify',
          isLoading: _isVerifying,
          onPressed: _isCodeComplete ? () => _onVerify() : null,
        ),
        const SizedBox(height: 24),
        _ResendRow(
          remaining: _remaining,
          isResending: _isResending,
          onResend: _onResend,
        ),
      ],
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.remaining,
    required this.isResending,
    required this.onResend,
  });

  final Duration remaining;
  final bool isResending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canResend = remaining <= Duration.zero && !isResending;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Didn't receive the code? ",
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        if (isResending)
          const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (canResend)
          GestureDetector(
            onTap: onResend,
            child: const Text(
              'Resend',
              style: TextStyle(color: _brandColor, fontWeight: FontWeight.w700),
            ),
          )
        else
          Text(
            'Resend in 0:${remaining.inSeconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

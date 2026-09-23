import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/core/validators/form_validators.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';
import 'package:resqconnect/shared/widgets/app_text_field.dart';
import 'package:resqconnect/shared/widgets/primary_button.dart';
import 'package:resqconnect/shared/widgets/app_card.dart';
import 'package:resqconnect/shared/widgets/responsive_layout.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const int _resendCooldownSeconds = 60;

  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
      } else {
        setState(() => _resendSecondsRemaining -= 1);
      }
    });
  }

  String _maskPhone(String? phone) {
    if (phone == null || phone.length < 4) {
      return 'your phone';
    }
    final visible = phone.substring(phone.length - 4);
    final prefix = phone.substring(0, phone.length - 4).replaceAll(RegExp(r'\d'), '*');
    return '$prefix$visible';
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final authState = ref.read(authProvider);
    if (authState.verificationId == null && authState.status != AuthStatus.codeSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification session expired. Please request a new OTP.')),
      );
      context.go('/login');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(_codeController.text.trim());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_resendSecondsRemaining > 0) {
      return;
    }

    _codeController.clear();
    await ref.read(authProvider.notifier).resendOtp();
    _startResendCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isLoading = authState.status == AuthStatus.loading || _isSubmitting;
    final maskedPhone = _maskPhone(authState.phoneNumber);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null &&
          (next.status == AuthStatus.codeSent || next.status == AuthStatus.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    if (authState.status == AuthStatus.unauthenticated &&
        authState.verificationId == null &&
        authState.phoneNumber == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/login');
        }
      });
    }

    final otpForm = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: isLoading ? null : () => context.go('/login'),
          ),
          const SizedBox(height: AppTheme.spaceM),
          Text(
            'Security Verification',
            style: AppTheme.headlineMedium.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceS),
          Text(
            'Enter the 6-digit security code sent to $maskedPhone.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spaceL),
          AppTextField(
            controller: _codeController,
            labelText: 'Verification Code',
            hintText: '000000',
            prefixIcon: Icons.lock_outline_rounded,
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: FormValidators.validateOtp,
          ),
          const SizedBox(height: AppTheme.spaceL),
          PrimaryButton(
            label: 'Verify and Proceed',
            icon: Icons.verified_user_rounded,
            isLoading: isLoading,
            onPressed: isLoading ? null : _submit,
          ),
          const SizedBox(height: AppTheme.spaceM),
          Center(
            child: TextButton(
              onPressed: (_resendSecondsRemaining > 0 || isLoading) ? null : _resend,
              child: Text(
                _resendSecondsRemaining > 0
                    ? 'Resend code in ${_resendSecondsRemaining}s'
                    : 'Resend OTP Code',
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceL),
            child: ResponsiveLayout(
              mobile: otpForm,
              tablet: Center(
                child: SizedBox(
                  width: 450,
                  child: AppCard(child: otpForm),
                ),
              ),
              desktop: Center(
                child: SizedBox(
                  width: 450,
                  child: AppCard(child: otpForm),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

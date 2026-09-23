import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/core/validators/form_validators.dart';
import 'package:resqconnect/features/auth/presentation/providers/auth_provider.dart';
import 'package:resqconnect/shared/widgets/app_text_field.dart';
import 'package:resqconnect/shared/widgets/primary_button.dart';
import 'package:resqconnect/shared/widgets/app_card.dart';
import 'package:resqconnect/shared/widgets/responsive_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text.trim();
      debugPrint('[DEBUG_LOGIN_PAGE] Form validated. Submitting phone number.');
      ref.read(authProvider.notifier).requestPhoneOtp(phone);
    } else {
      debugPrint('[DEBUG_LOGIN_PAGE] Form validation failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Show auth errors on the login screen; navigation is handled by GoRouter.
    ref.listen<AuthState>(authProvider, (previous, next) {
      debugPrint('[DEBUG_LOGIN_PAGE] AuthState changed: previous=${previous?.status} -> next=${next.status}');
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        debugPrint('[DEBUG_LOGIN_PAGE] AuthStatus.error detected. Showing SnackBar.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    final loginForm = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Emergency Access',
            style: AppTheme.headlineMedium.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceS),
          Text(
            'Please verify your phone number to proceed to the emergency coordination feed.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spaceL),
          
          // Reusable form validation input (Task 8)
          AppTextField(
            controller: _phoneController,
            labelText: 'Phone Number',
            hintText: '+15555555555',
            prefixIcon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            validator: FormValidators.validatePhone,
          ),
          const SizedBox(height: AppTheme.spaceL),
          
          PrimaryButton(
            label: 'Request OTP Code',
            icon: Icons.sms_rounded,
            isLoading: authState.status == AuthStatus.loading,
            onPressed: _submit,
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
              mobile: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.contact_phone_rounded,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppTheme.spaceXL),
                  loginForm,
                ],
              ),
              tablet: Center(
                child: SizedBox(
                  width: 500,
                  child: AppCard(
                    title: const Text('ResQConnect Portal'),
                    subtitle: const Text('Emergency Response Coordination'),
                    child: loginForm,
                  ),
                ),
              ),
              desktop: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 400,
                    padding: const EdgeInsets.all(AppTheme.spaceL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.campaign_rounded, size: 64, color: theme.colorScheme.primary),
                        const SizedBox(height: AppTheme.spaceM),
                        Text(
                          'ResQConnect Portal',
                          style: AppTheme.headlineLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppTheme.spaceS),
                        Text(
                          'Phase 2 active rescue coordination. Authenticate to join response channels.',
                          style: AppTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXL),
                  SizedBox(
                    width: 500,
                    child: AppCard(
                      child: loginForm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

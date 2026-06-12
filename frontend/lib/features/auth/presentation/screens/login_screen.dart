import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/custom_button.dart';
import '../../../../shared/custom_textfield.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).login(
            _mobileController.text.trim(),
            _passwordController.text.trim(),
          );
      if (success && mounted) {
        context.go(AppRouter.mapPath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.marineGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dynamic Brand Header
                    Center(
                      child: Container(
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.oceanBlue.withOpacity(0.2),
                          border: Border.all(color: AppColors.aquamarine, width: 2),
                        ),
                        child: const Icon(
                          Icons.sailing_rounded,
                          size: 50,
                          color: AppColors.aquamarine,
                        ),
                      ),
                    ).animate().scale(delay: 200.ms, duration: 400.ms),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.translate('appTitle').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 26,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                            color: AppColors.sunlightHighContrast,
                          ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 8),
                    const Text(
                      'DEEP SEA NAVIGATION & LIFELINE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.skyBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 48),

                    // Inputs Section
                    CustomTextField(
                      labelText: AppLocalizations.translate('mobileNumber'),
                      hintText: 'Enter 10-digit number',
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_android_rounded,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter mobile number';
                        }
                        return null;
                      },
                    ).animate().slideY(begin: 0.1, delay: 500.ms),
                    const SizedBox(height: 20),
                    CustomTextField(
                      labelText: AppLocalizations.translate('password'),
                      hintText: 'Enter password',
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        return null;
                      },
                    ).animate().slideY(begin: 0.1, delay: 600.ms),
                    const SizedBox(height: 12),

                    // Auth error display
                    if (authState.errorMessage != null) ...[
                      Text(
                        authState.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.crimsonAlert,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ).animate().shake(),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 24),
                    CustomButton(
                      text: AppLocalizations.translate('signin'),
                      isLoading: authState.isLoading,
                      onPressed: _submit,
                    ).animate().slideY(begin: 0.2, delay: 700.ms),
                    const SizedBox(height: 24),

                    // Toggle Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "New to system? ",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.push(AppRouter.registerPath);
                          },
                          child: const Text(
                            "Register Vessel",
                            style: TextStyle(
                              color: AppColors.aquamarine,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

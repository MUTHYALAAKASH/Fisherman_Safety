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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // User controllers
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Boat controllers
  final _boatNameController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _harborController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _boatNameController.dispose();
    _regNumberController.dispose();
    _harborController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).register(
            fullName: _fullNameController.text.trim(),
            mobileNumber: _mobileController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            password: _passwordController.text.trim(),
            boatName: _boatNameController.text.trim().isEmpty ? null : _boatNameController.text.trim(),
            registrationNumber: _regNumberController.text.trim().isEmpty ? null : _regNumberController.text.trim(),
            harborLocation: _harborController.text.trim().isEmpty ? null : _harborController.text.trim(),
          );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vessel registered successfully! Please login.'),
            backgroundColor: AppColors.safetyGreen,
          ),
        );
        context.go(AppRouter.loginPath);
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
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.translate('register').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 26,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                            color: AppColors.sunlightHighContrast,
                          ),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 8),
                    const Text(
                      'PROVISION NEW VESSEL & FISHERMAN CREDENTIALS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.skyBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 36),

                    // SECTION 1: Personal Details
                    const Text(
                      '1. Fisher Personal Details',
                      style: TextStyle(color: AppColors.aquamarine, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Divider(color: AppColors.cardNavy, thickness: 1.5),
                    const SizedBox(height: 12),
                    CustomTextField(
                      labelText: AppLocalizations.translate('fullName'),
                      hintText: 'Enter your full name',
                      controller: _fullNameController,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      labelText: AppLocalizations.translate('mobileNumber'),
                      hintText: 'Enter 10-digit number',
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_android_rounded,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mobile number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      labelText: 'Email Address (Optional)',
                      hintText: 'Enter email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      labelText: AppLocalizations.translate('password'),
                      hintText: 'Create strong password',
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // SECTION 2: Boat Details
                    const Text(
                      '2. Vessel Details (Optional)',
                      style: TextStyle(color: AppColors.aquamarine, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Divider(color: AppColors.cardNavy, thickness: 1.5),
                    const SizedBox(height: 12),
                    CustomTextField(
                      labelText: AppLocalizations.translate('boatName'),
                      hintText: 'Enter boat name',
                      controller: _boatNameController,
                      prefixIcon: Icons.directions_boat_filled_outlined,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      labelText: AppLocalizations.translate('regNumber'),
                      hintText: 'Enter maritime registration ID',
                      controller: _regNumberController,
                      prefixIcon: Icons.badge_outlined,
                      validator: (value) {
                        if (_boatNameController.text.trim().isNotEmpty && (value == null || value.isEmpty)) {
                          return 'Registration number required if Boat Name is filled';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      labelText: AppLocalizations.translate('harbor'),
                      hintText: 'Enter base port/harbor location',
                      controller: _harborController,
                      prefixIcon: Icons.anchor_rounded,
                    ),
                    const SizedBox(height: 16),

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
                      text: AppLocalizations.translate('signup'),
                      isLoading: authState.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 24),

                    // Switch back to Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already registered? ",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.pop();
                          },
                          child: const Text(
                            "Sign In Instead",
                            style: TextStyle(
                              color: AppColors.aquamarine,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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

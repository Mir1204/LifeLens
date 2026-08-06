import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthenticated});

  final ValueChanged<AppUser> onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: 'Mir Patel');
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isSignup = false;
  bool isLoading = false;
  bool obscurePassword = true;
  String? errorText;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Text(
                        'L',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isSignup ? 'Create Account' : 'Welcome Back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track your daily lifestyle scores with LifeLens.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 22),
                    if (isSignup) ...[
                      TextFormField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() => obscurePassword = !obscurePassword);
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.length < 4
                          ? 'Use at least 4 characters'
                          : null,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: isLoading ? null : _submit,
                      icon: Icon(isSignup ? Icons.person_add : Icons.login),
                      label: Text(isSignup ? 'Sign Up' : 'Login'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                isSignup = !isSignup;
                                errorText = null;
                              });
                            },
                      child: Text(
                        isSignup
                            ? 'Already have an account? Login'
                            : 'New here? Create account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final user = isSignup
          ? await authService.signUp(
              name: nameController.text,
              email: emailController.text,
              password: passwordController.text,
            )
          : await authService.login(
              email: emailController.text,
              password: passwordController.text,
            );
      widget.onAuthenticated(user);
    } on AuthException catch (error) {
      setState(() => errorText = error.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}

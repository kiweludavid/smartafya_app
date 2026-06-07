import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'app_palette.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../utils/dio_error_message.dart';

class SmartAfyaLoginScreen extends StatefulWidget {
  const SmartAfyaLoginScreen({super.key});

  @override
  State<SmartAfyaLoginScreen> createState() => _SmartAfyaLoginScreenState();
}

class _SmartAfyaLoginScreenState extends State<SmartAfyaLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      await _authService.login(email: email, password: password);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: email);
    } on DioException catch (e) {
      if (!mounted) return;
      final message = messageFromDioException(e) ?? 'Login failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      subtitle: 'Your Mental Health Matters',
      child: AuthCard(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SmartAfyaInputField(
                controller: _emailController,
                hint: 'Email',
                helperText: 'Use your account email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Please enter your email.';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SmartAfyaInputField(
                controller: _passwordController,
                hint: 'Password',
                helperText: 'At least 8 characters',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: SmartAfyaPalette.primaryBlue,
                  ),
                ),
                validator: (value) {
                  final v = value ?? '';
                  if (v.isEmpty) return 'Please enter your password.';
                  if (v.length < 8) return 'Password must be at least 8 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryActionButton(
                label: 'Login',
                isLoading: _isLoading,
                onPressed: _onLoginPressed,
              ),
              const SizedBox(height: 14),
              BottomAuthLink(
                prefix: "Don't have an account? ",
                action: 'Sign Up',
                onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

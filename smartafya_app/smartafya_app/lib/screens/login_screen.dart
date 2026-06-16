import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'app_palette.dart';
import 'auth_widgets.dart';
import '../l10n/l10n_extensions.dart';
import '../services/auth_service.dart';
import '../utils/dio_error_message.dart';
import '../widgets/language_picker.dart';

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
      final message = messageFromDioException(e) ?? context.l10n.loginFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loginFailed)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthPageScaffold(
      subtitle: l10n.loginSubtitle,
      child: AuthCard(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LanguagePicker(compact: true),
              const SizedBox(height: 8),
              SmartAfyaInputField(
                controller: _emailController,
                hint: l10n.email,
                helperText: l10n.emailHelper,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return l10n.pleaseEnterEmail;
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                    return l10n.enterValidEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SmartAfyaInputField(
                controller: _passwordController,
                hint: l10n.password,
                helperText: l10n.passwordHelper,
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
                  if (v.isEmpty) return l10n.pleaseEnterPassword;
                  if (v.length < 8) return l10n.passwordMinLength;
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(l10n.forgotPassword),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryActionButton(
                label: l10n.login,
                isLoading: _isLoading,
                onPressed: _onLoginPressed,
              ),
              const SizedBox(height: 14),
              BottomAuthLink(
                prefix: l10n.dontHaveAccount,
                action: l10n.signUp,
                onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

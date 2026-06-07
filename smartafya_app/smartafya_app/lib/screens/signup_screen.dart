import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'app_palette.dart';
import 'auth_widgets.dart';
import '../services/auth_service.dart';
import '../utils/dio_error_message.dart';

class SmartAfyaSignupScreen extends StatefulWidget {
  const SmartAfyaSignupScreen({super.key});

  @override
  State<SmartAfyaSignupScreen> createState() => _SmartAfyaSignupScreenState();
}

class _SmartAfyaSignupScreenState extends State<SmartAfyaSignupScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedRole = 'client';
  String? _selectedSpecialistType;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  static bool _isValidEmail(String v) => RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);

  static bool _isValidPhone(String v) {
    final digits = v.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^\+?[0-9]{9,15}$').hasMatch(digits);
  }

  static bool _isStrongPassword(String v) {
    // >= 8 chars, at least 1 uppercase, at least 1 special character.
    return RegExp(r'^(?=.*[A-Z])(?=.*[^A-Za-z0-9]).{8,}$').hasMatch(v);
  }

  Future<void> _onSignupPressed() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final role = _selectedRole;
    final specialistType = role == 'doctor' ? _selectedSpecialistType : null;

    setState(() => _isLoading = true);
    try {
      await _authService.register(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
        role: role,
        specialistType: specialistType,
      );
      await _authService.login(email: email, password: password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully.')),
      );
      Navigator.pushReplacementNamed(context, '/home', arguments: fullName);
    } on DioException catch (e) {
      if (!mounted) return;
      final message = messageFromDioException(e) ?? 'Sign up failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign up failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = _selectedRole == 'doctor';
    return AuthPageScaffold(
      subtitle: 'Create your account and start your mental wellness journey',
      child: AuthCard(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoleCard(
                selectedRole: _selectedRole,
                onChanged: _isLoading
                    ? null
                    : (r) => setState(() {
                          _selectedRole = r;
                          if (_selectedRole != 'doctor') _selectedSpecialistType = null;
                        }),
              ),
              const SizedBox(height: 12),
              SmartAfyaInputField(
                controller: _fullNameController,
                hint: 'Full Name',
                helperText: 'Use your real name for your profile',
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Please enter your full name.';
                  if (v.length < 3) return 'Name should be at least 3 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SmartAfyaInputField(
                controller: _emailController,
                hint: 'Email',
                helperText: 'We will send verification to this email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Please enter your email.';
                  if (!_isValidEmail(v)) return 'Enter a valid email address.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SmartAfyaInputField(
                controller: _phoneController,
                hint: 'Phone Number',
                helperText: 'Include country code (e.g. +255...)',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: isDoctor ? TextInputAction.next : TextInputAction.next,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Please enter your phone number.';
                  if (!_isValidPhone(v)) return 'Enter a valid phone number.';
                  return null;
                },
              ),
              if (isDoctor) ...[
                const SizedBox(height: 12),
                _SpecialistTypeField(
                  value: _selectedSpecialistType,
                  enabled: !_isLoading,
                  onChanged: (v) => setState(() => _selectedSpecialistType = v),
                ),
              ],
              const SizedBox(height: 12),
              SmartAfyaInputField(
                controller: _passwordController,
                hint: 'Password',
                helperText: '8+ chars, 1 uppercase, 1 special character',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
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
                  if (!_isStrongPassword(v)) {
                    return 'Use 8+ chars with 1 uppercase and 1 special character.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SmartAfyaInputField(
                controller: _confirmPasswordController,
                hint: 'Confirm Password',
                helperText: 'Re-enter your password',
                icon: Icons.lock_person_outlined,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: SmartAfyaPalette.primaryBlue,
                  ),
                ),
                validator: (value) {
                  final v = value ?? '';
                  if (v.isEmpty) return 'Please confirm your password.';
                  if (v != _passwordController.text) return 'Passwords do not match.';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: 'Sign Up',
                isLoading: _isLoading,
                onPressed: _onSignupPressed,
              ),
              const SizedBox(height: 16),
              BottomAuthLink(
                prefix: 'Already have an account? ',
                action: 'Login',
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selectedRole,
    required this.onChanged,
  });

  final String selectedRole;
  final void Function(String role)? onChanged;

  static const _hairline = Color(0xFFE4EEF7);

  @override
  Widget build(BuildContext context) {
    Widget pill({
      required String role,
      required String label,
      required IconData icon,
      required Color accent,
    }) {
      final selected = selectedRole == role;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onChanged == null ? null : () => onChanged!(role),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.10) : const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? accent.withValues(alpha: 0.35) : _hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? accent : SmartAfyaPalette.mutedText),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: selected ? accent : SmartAfyaPalette.deepText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isPrivileged = selectedRole == 'doctor';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Role',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SmartAfyaPalette.mutedText,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              pill(role: 'client', label: 'Client', icon: Icons.person_outline, accent: SmartAfyaPalette.primaryGreen),
              const SizedBox(width: 10),
              pill(role: 'doctor', label: 'Doctor', icon: Icons.medical_services_outlined, accent: SmartAfyaPalette.primaryBlue),
            ],
          ),
          if (isPrivileged) const SizedBox(height: 0),
        ],
      ),
    );
  }
}

class _SpecialistTypeField extends StatelessWidget {
  const _SpecialistTypeField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String? value;
  final bool enabled;
  final void Function(String? value) onChanged;

  static const _hairline = Color(0xFFE4EEF7);

  static const _options = <String, String>{
    'Psychologist': 'psychologist',
    'Psychiatrist': 'psychiatrist',
    'Therapist': 'therapist',
    'Cleric': 'cleric',
    'Influencer': 'influencer',
  };

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: _options.entries
          .map(
            (e) => DropdownMenuItem<String>(
              value: e.value,
              child: Text(
                e.key,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (v) {
        final selected = (v ?? '').trim();
        if (selected.isEmpty) return 'Please select your specialist type.';
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Specialist Type',
        helperText: 'Required for doctor accounts',
        filled: true,
        fillColor: const Color(0xFFF7FAFD),
        prefixIcon: const Icon(Icons.badge_outlined, color: SmartAfyaPalette.primaryBlue),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.6), width: 1.5),
        ),
      ),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

/// Client profile screen backed by:
/// - `GET /users/me`
/// - `PATCH /users/me` (allowed fields: full_name, phone, specialist_type)
///
/// For clients we allow editing: full name + phone.
class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _api = ApiService();
  final _auth = AuthService();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  CurrentUserDto? _me;

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _api.fetchCurrentUser().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _me = me;
        _fullNameController.text = me.fullName.trim();
        _phoneController.text = (me.phone ?? '').trim();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Could not load profile.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load profile.';
      });
    }
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final me = _me;
    if (me == null) return;

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();

    final noChange = fullName == me.fullName.trim() && phone == (me.phone ?? '').trim();
    if (noChange) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No changes to save.')));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await _api
          .patchCurrentUser(
            fullName: fullName,
            phone: phone.isEmpty ? null : phone,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _me = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = messageFromDioException(e) ?? 'Could not update profile.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update profile.';
      });
    }
  }

  Future<void> _logout() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (go != true) return;

    await _auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        body: Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        appBar: AppBar(
          title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: SmartAfyaPalette.scaffoldBg,
          elevation: 0,
          foregroundColor: SmartAfyaPalette.deepText,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _load,
                  style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final me = _me!;
    final roleLabel = me.isDoctor ? 'Doctor' : 'Client';

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        actions: [
          IconButton(
            onPressed: _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _profileHeader(me, roleLabel),
              const SizedBox(height: 16),
              _card(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Personal details', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fullNameController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration('Full name', icon: Icons.person_outline_rounded),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.length < 3) return 'Please enter your full name.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        decoration: _inputDecoration('Phone (optional)', icon: Icons.phone_outlined),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          if (t.length < 8) return 'Please enter a valid phone number.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _readOnlyRow('Email', me.email),
                      const SizedBox(height: 8),
                      _readOnlyRow('Role', roleLabel),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Security', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Color(0xFFFFD7D7)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(CurrentUserDto me, String roleLabel) {
    final initials = me.fullName.trim().isEmpty
        ? '?'
        : me.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: SmartAfyaPalette.softBlue,
            child: Text(
              initials,
              style: const TextStyle(color: SmartAfyaPalette.primaryBlue, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(me.fullName.trim().isEmpty ? 'Your profile' : me.fullName.trim(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: SmartAfyaPalette.softBlue,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE4EEF7)),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(color: SmartAfyaPalette.primaryBlue, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }

  static InputDecoration _inputDecoration(String label, {required IconData icon}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: SmartAfyaPalette.softBlue,
      prefixIcon: Icon(icon, color: SmartAfyaPalette.primaryBlue),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x96206FB5), width: 1.4),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

/// Profile for doctors: loads `GET /users/me`, edits via `PATCH /users/me`,
/// availability via `PATCH /users/me/availability` (same as backend `UserOut` / `UserUpdate`).
class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key, this.onRefreshParent});

  /// Called after successful save or availability change so home can reload `/users/me`.
  final Future<void> Function()? onRefreshParent;

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  static const _hairline = Color(0xFFE4EEF7);
  static const _cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 6)),
  ];

  /// Matches [SpecialistType] in `smart_afya/app/models/user.py`.
  static const _specialistKeys = [
    'psychologist',
    'psychiatrist',
    'therapist',
    'cleric',
    'influencer',
    'general',
  ];

  bool _loading = true;
  bool _saving = false;
  bool _availabilityBusy = false;
  String? _error;
  CurrentUserDto? _user;
  String? _specialistValue;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _notifyParent() async {
    final f = widget.onRefreshParent;
    if (f != null) await f();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await _api.fetchCurrentUser().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (!u.isDoctor) {
        setState(() {
          _loading = false;
          _error = 'This profile is only for doctor accounts.';
        });
        return;
      }
      _nameController.text = u.fullName;
      _phoneController.text = u.phone ?? '';
      setState(() {
        _user = u;
        _specialistValue = u.specialistType;
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await _api
          .patchCurrentUser(
            fullName: _nameController.text,
            phone: _phoneController.text,
            specialistType: _specialistValue ?? '',
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() => _user = updated);
      await _notifyParent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not save.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleAvailability(bool next) async {
    final u = _user;
    if (u == null || _availabilityBusy) return;
    setState(() {
      _availabilityBusy = true;
      _user = CurrentUserDto(
        id: u.id,
        fullName: u.fullName,
        email: u.email,
        role: u.role,
        specialistType: u.specialistType,
        isActive: u.isActive,
        isAvailable: next,
        phone: u.phone,
        isVerified: u.isVerified,
        baseLatitude: u.baseLatitude,
        baseLongitude: u.baseLongitude,
        createdAt: u.createdAt,
      );
    });
    try {
      await _api.updateDoctorAvailability(isAvailable: next).timeout(const Duration(seconds: 8));
      final fresh = await _api.fetchCurrentUser().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _user = fresh);
      await _notifyParent();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _user = u);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not update availability.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _user = u);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update availability.')));
    } finally {
      if (mounted) setState(() => _availabilityBusy = false);
    }
  }

  static String _specialistLabel(String key) {
    return key
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _shortId(String id) {
    final t = id.trim();
    if (t.length <= 8) return t;
    return '…${t.substring(t.length - 6)}';
  }

  static String? _formatMemberSince(DateTime? dt) {
    if (dt == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = months[(dt.month - 1).clamp(0, 11)];
    return '$m ${dt.day}, ${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: SmartAfyaPalette.primaryBlue,
                  onRefresh: _load,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        _ProfileCard(
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.medical_services_rounded, color: SmartAfyaPalette.primaryBlue, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _user?.fullName ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: SmartAfyaPalette.deepText),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _user?.specialistType != null && _user!.specialistType!.isNotEmpty
                                          ? _specialistLabel(_user!.specialistType!)
                                          : 'Specialist',
                                      style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProfileCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 12),
                              _readonlyRow(Icons.email_outlined, 'Email', _user?.email ?? '—'),
                              _readonlyRow(Icons.badge_outlined, 'User ID', _shortId(_user?.id ?? '')),
                              if (_formatMemberSince(_user?.createdAt) != null)
                                _readonlyRow(Icons.event_outlined, 'Member since', _formatMemberSince(_user!.createdAt)!),
                              _readonlyRow(
                                Icons.verified_outlined,
                                'Verified',
                                (_user?.isVerified ?? false) ? 'Yes' : 'No',
                              ),
                              _readonlyRow(
                                Icons.person_outline,
                                'Account status',
                                (_user?.isActive ?? false) ? 'Active' : 'Inactive',
                              ),
                            ],
                          ),
                        ),
                        if (_user?.baseLatitude != null && _user?.baseLongitude != null) ...[
                          const SizedBox(height: 12),
                          _ProfileCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Service base location', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                const SizedBox(height: 6),
                                Text(
                                  '${_user!.baseLatitude!.toStringAsFixed(5)}, ${_user!.baseLongitude!.toStringAsFixed(5)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: SmartAfyaPalette.deepText),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Used for assignments. Updated by your administrator.',
                                  style: TextStyle(fontSize: 12.5, color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _ProfileCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: _fieldDecoration('Full name'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name.' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: _fieldDecoration('Phone'),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String?>(
                                value: _specialistValue,
                                decoration: _fieldDecoration('Specialty'),
                                hint: const Text('Select specialty'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Not set'),
                                  ),
                                  ..._specialistKeys.map(
                                    (k) => DropdownMenuItem<String?>(
                                      value: k,
                                      child: Text(_specialistLabel(k)),
                                    ),
                                  ),
                                  if (_specialistValue != null &&
                                      _specialistValue!.isNotEmpty &&
                                      !_specialistKeys.contains(_specialistValue))
                                    DropdownMenuItem<String?>(
                                      value: _specialistValue,
                                      child: Text(_specialistLabel(_specialistValue!)),
                                    ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _specialistValue = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProfileCard(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _user?.isAvailable ?? false,
                            onChanged: _availabilityBusy ? null : (v) => _toggleAvailability(v),
                            title: const Text('Available for new sessions', style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text(
                              _availabilityBusy
                                  ? 'Updating…'
                                  : ((_user?.isAvailable ?? false)
                                      ? 'Patients can book you when slots are open.'
                                      : 'You are hidden from new bookings.'),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            activeThumbColor: SmartAfyaPalette.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: SmartAfyaPalette.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  static InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF7FAFD),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _hairline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _hairline)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.55), width: 1.5),
      ),
    );
  }

  static Widget _readonlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: SmartAfyaPalette.mutedText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: SmartAfyaPalette.mutedText)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: SmartAfyaPalette.deepText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DoctorProfileScreenState._hairline),
        boxShadow: _DoctorProfileScreenState._cardShadow,
      ),
      child: child,
    );
  }
}

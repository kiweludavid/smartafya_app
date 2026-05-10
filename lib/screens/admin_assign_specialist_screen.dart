import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

class AdminAssignSpecialistScreen extends StatefulWidget {
  const AdminAssignSpecialistScreen({super.key});

  @override
  State<AdminAssignSpecialistScreen> createState() => _AdminAssignSpecialistScreenState();
}

class _AdminAssignSpecialistScreenState extends State<AdminAssignSpecialistScreen> {
  final _api = ApiService();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<AdminUserDto> _clients = [];
  List<DoctorDto> _doctorsAll = [];
  List<SessionDto> _sessions = [];
  List<BookingDto> _bookings = [];

  String? _clientId;
  String? _sessionId;
  String? _doctorId;
  DateTime? _scheduledLocal;

  bool _autoLink = true;
  final _meetingLink = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _meetingLink.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchAllUsersForAdmin(),
        _api.fetchDoctors(availableOnly: false),
        _api.fetchSessions(),
        _api.fetchAllBookings(),
      ]);
      final users = results[0] as List<AdminUserDto>;
      final doctors = results[1] as List<DoctorDto>;
      final sessions = results[2] as List<SessionDto>;
      final bookings = results[3] as List<BookingDto>;

      final clients = users.where((u) => u.isActive && u.isClient).toList()
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      doctors.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _clients = clients;
        _doctorsAll = doctors;
        _sessions = sessions;
        _bookings = bookings;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load data.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load data.';
      });
    }
  }

  String _shortId(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

  BookingDto? _bookingForSessionId(String? sessionId) {
    if (sessionId == null || sessionId.trim().isEmpty) return null;
    final s = _sessions.where((x) => x.id == sessionId).toList();
    if (s.isEmpty) return null;
    final bookingId = s.first.bookingId;
    final b = _bookings.where((x) => x.id == bookingId).toList();
    return b.isEmpty ? null : b.first;
  }

  bool _isPhysicalSession(String? sessionId) {
    final b = _bookingForSessionId(sessionId);
    if (b == null) return false;
    return b.sessionType.toLowerCase().trim() == 'physical';
  }

  String _sessionTypeLabel(String? sessionId) {
    final b = _bookingForSessionId(sessionId);
    final raw = (b?.sessionType ?? '').toLowerCase().trim();
    if (raw == 'physical') return 'Physical';
    if (raw.isEmpty) return 'Online';
    // backend booking uses audio|video|physical, all non-physical map to online for meeting link
    return 'Online';
  }

  DateTime? _bookingFirstPreferredUtc(String? sessionId) {
    final b = _bookingForSessionId(sessionId);
    return b?.firstPreferredDateUtc;
  }

  String _formatPreferred(DateTime? utc) {
    if (utc == null) return 'No preferred slot';
    final dt = utc.toLocal();
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final d = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return '$d · $hour12:$min $ampm';
  }

  List<SessionDto> _assignableSessions() {
    final byClient = (_clientId == null || _clientId!.trim().isEmpty)
        ? _sessions
        : _sessions.where((s) => s.clientId == _clientId).toList();

    final list = byClient.where((s) {
      final st = s.status.toLowerCase();
      if (st == 'cancelled' || st == 'completed') return false;
      final hasDoctor = (s.doctorId ?? '').trim().isNotEmpty;
      final hasSchedule = (s.scheduledAt ?? '').trim().isNotEmpty;
      // We focus on "assign specialist" = doctor missing; scheduling is part of assign endpoint anyway.
      // Allow already scheduled but unassigned (rare) by permitting !hasDoctor.
      return !hasDoctor && !hasSchedule;
    }).toList();

    // Prefer physical sessions later? keep stable, but show earliest preferred first.
    list.sort((a, b) {
      final ap = _bookingFirstPreferredUtc(a.id) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bp = _bookingFirstPreferredUtc(b.id) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return ap.compareTo(bp);
    });
    return list;
  }

  List<DoctorDto> _filteredDoctors() {
    // Backend only enforces availability for NON-physical sessions.
    if (_isPhysicalSession(_sessionId)) return _doctorsAll;
    return _doctorsAll.where((d) => d.isAvailable).toList();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final base = _scheduledLocal ?? now.add(const Duration(hours: 2));

    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(base.year, base.month, base.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d == null || !mounted) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (t == null || !mounted) return;

    setState(() => _scheduledLocal = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  String _formatWhen(DateTime? dt) {
    if (dt == null) return 'Pick date & time';
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final d = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return '$d · $hour12:$min $ampm';
  }

  String _sessionLabel(SessionDto s) {
    final type = _sessionTypeLabel(s.id);
    final pref = _formatPreferred(_bookingFirstPreferredUtc(s.id));
    return '$type · $pref · booking …${_shortId(s.bookingId)} · session …${_shortId(s.id)}';
  }

  String _suggestedMeetingLink() {
    final sid = _sessionId ?? 'session';
    // backend auto-creates https://meet.smartafya.com/session/{id} if meeting_link is omitted
    return 'https://meet.smartafya.com/session/${_shortId(sid)}';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final sessionId = _sessionId!;
    final doctorId = _doctorId!;
    final local = _scheduledLocal!;
    final scheduledAtUtcIso = local.toUtc().toIso8601String();

    final isPhysical = _isPhysicalSession(sessionId);
    final meetingLink = isPhysical
        ? null
        : (_autoLink ? null : _meetingLink.text.trim()); // let backend generate if auto

    setState(() => _saving = true);
    try {
      await _api.assignSessionDoctor(
        sessionId: sessionId,
        doctorId: doctorId,
        scheduledAtIso: scheduledAtUtcIso,
        meetingLink: meetingLink,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Specialist assigned and session scheduled.')));
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Assignment failed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment failed.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _assignableSessions();
    final docs = _filteredDoctors();
    final isPhysical = _isPhysicalSession(_sessionId);

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Assign specialist', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue))
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 30),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _load,
                        style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _Card(
                          title: 'Pick request',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _clientId,
                                decoration: const InputDecoration(labelText: 'Client', filled: true),
                                items: _clients
                                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.fullName.isEmpty ? c.email : c.fullName)))
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (v) {
                                        setState(() {
                                          _clientId = v;
                                          _sessionId = null;
                                          _doctorId = null;
                                          _scheduledLocal = null;
                                        });
                                      },
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Client is required.' : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _sessionId,
                                decoration: const InputDecoration(labelText: 'Unassigned session', filled: true),
                                items: sessions
                                    .map((s) => DropdownMenuItem<String>(
                                          value: s.id,
                                          child: Text(_sessionLabel(s), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (v) {
                                        setState(() {
                                          _sessionId = v;
                                          _doctorId = null;
                                          _scheduledLocal = null;
                                          _autoLink = true;
                                          _meetingLink.text = '';
                                        });
                                      },
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Session is required.' : null,
                              ),
                              if (_clientId != null && _clientId!.trim().isNotEmpty && sessions.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, left: 12),
                                  child: Text(
                                    'No unassigned + unscheduled sessions for this client.',
                                    style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              InputDecorator(
                                decoration: const InputDecoration(labelText: 'Session type (from booking)', filled: true),
                                child: Text(_sessionTypeLabel(_sessionId), style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Card(
                          title: 'Assign specialist & schedule',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _doctorId,
                                decoration: InputDecoration(
                                  labelText: isPhysical ? 'Specialist (any doctor)' : 'Specialist (available only)',
                                  filled: true,
                                ),
                                items: docs
                                    .map(
                                      (d) => DropdownMenuItem<String>(
                                        value: d.id,
                                        child: Text(d.fullName.isEmpty ? d.email : d.fullName),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving ? null : (v) => setState(() => _doctorId = v),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Specialist is required.' : null,
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _saving ? null : _pickDateTime,
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Date & time', filled: true),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(_formatWhen(_scheduledLocal), style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                      const Icon(Icons.schedule_rounded, color: SmartAfyaPalette.primaryBlue),
                                    ],
                                  ),
                                ),
                              ),
                              if (_scheduledLocal == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, left: 12),
                                  child: Text('Date & time is required.', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              const SizedBox(height: 12),
                              if (!isPhysical) ...[
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _autoLink,
                                  onChanged: _saving ? null : (v) => setState(() => _autoLink = v),
                                  title: const Text('Auto-generate meeting link', style: TextStyle(fontWeight: FontWeight.w900)),
                                  subtitle: Text('Default: ${_suggestedMeetingLink()}'),
                                ),
                                if (!_autoLink) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _meetingLink,
                                    enabled: !_saving,
                                    decoration: const InputDecoration(
                                      labelText: 'Meeting link (optional)',
                                      hintText: 'https://…',
                                      filled: true,
                                    ),
                                  ),
                                ],
                              ] else ...[
                                const Text(
                                  'Physical sessions: meeting link is optional. If omitted, backend may set a Google Maps link (if address exists).',
                                  style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.3),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  if (_scheduledLocal == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date & time is required.')));
                                    return;
                                  }
                                  _submit();
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: SmartAfyaPalette.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                          child: Text(_saving ? 'Assigning…' : 'Assign specialist', style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF7FAFD),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}


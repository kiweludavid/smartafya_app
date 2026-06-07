import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

enum _SessionTypeUi { online, physical }
enum _PhysicalLocationUi { clinic, clientAddress, custom }

class AdminScheduleSessionScreen extends StatefulWidget {
  const AdminScheduleSessionScreen({
    super.key,
    this.initialClientId,
    this.initialSessionId,
  });

  final String? initialClientId;
  final String? initialSessionId;

  @override
  State<AdminScheduleSessionScreen> createState() => _AdminScheduleSessionScreenState();
}

class _AdminScheduleSessionScreenState extends State<AdminScheduleSessionScreen> {
  final _api = ApiService();
  bool _appliedInitialSelection = false;

  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _submitted = false;

  List<AdminUserDto> _clients = [];
  List<DoctorDto> _specialists = [];
  List<SessionDto> _existingSessions = [];
  List<BookingDto> _bookings = [];

  String? _clientId;
  String? _doctorId;
  String? _sessionId;
  DateTime? _scheduledLocal;
  int _durationMinutes = 60; // used for double-booking window
  _SessionTypeUi _sessionTypeUi = _SessionTypeUi.online;
  bool _sessionTypeManuallySet = false;
  bool _autoGenerateLink = true;
  String _meetingPlatform = 'google_meet'; // 'google_meet' | 'zoom'
  final _meetingLink = TextEditingController();
  final _notes = TextEditingController();

  // Physical coordination (stored on booking historically; we persist into session notes for now)
  _PhysicalLocationUi _physicalLocationUi = _PhysicalLocationUi.clientAddress;
  final _physicalAddress = TextEditingController();
  final _physicalLat = TextEditingController();
  final _physicalLng = TextEditingController();
  final _physicalContactName = TextEditingController();
  final _physicalContactPhone = TextEditingController();
  final _physicalAccessNotes = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _meetingLink.dispose();
    _notes.dispose();
    _physicalAddress.dispose();
    _physicalLat.dispose();
    _physicalLng.dispose();
    _physicalContactName.dispose();
    _physicalContactPhone.dispose();
    _physicalAccessNotes.dispose();
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
        _api.fetchDoctors(availableOnly: true),
        _api.fetchSessions(),
        _api.fetchAllBookings(),
      ]);
      final users = results[0] as List<AdminUserDto>;
      final specialists = results[1] as List<DoctorDto>;
      final sessions = results[2] as List<SessionDto>;
      final bookings = results[3] as List<BookingDto>;

      final clients = users.where((u) => u.isActive && u.isClient).toList()
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      // Availability filter already applied by API, but keep local guard.
      final availableDocs = specialists.where((d) => d.isAvailable).toList()
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _clients = clients;
        _specialists = availableDocs;
        _existingSessions = sessions;
        _bookings = bookings;
        _loading = false;
      });

      if (!_appliedInitialSelection) {
        _appliedInitialSelection = true;
        final nextClientId = widget.initialClientId;
        final nextSessionId = widget.initialSessionId;
        if ((nextClientId ?? '').trim().isNotEmpty) {
          setState(() => _clientId = nextClientId);
        }
        if ((nextSessionId ?? '').trim().isNotEmpty) {
          setState(() => _sessionId = nextSessionId);
          _applySessionDefaults();
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load scheduling data.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load scheduling data.';
      });
    }
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

    if (_autoGenerateLink && _sessionTypeUi == _SessionTypeUi.online) {
      _meetingLink.text = _generatedMeetingLink();
    }
  }

  String _generatedMeetingLink() {
    // Backend will auto-generate a default link if meeting_link is omitted.
    // For UX, we generate a deterministic "suggested" link after date & time is selected.
    final sid = _sessionId ?? 'session';
    final tail = sid.length <= 6 ? sid : sid.substring(sid.length - 6);
    final when = _scheduledLocal?.toUtc().toIso8601String() ?? '';
    return 'https://meet.smartafya.com/session/$tail?platform=$_meetingPlatform&at=${Uri.encodeComponent(when)}';
  }

  bool _overlapsExisting({
    required String doctorId,
    required DateTime startUtc,
    required int durationMinutes,
  }) {
    final endUtc = startUtc.add(Duration(minutes: durationMinutes));

    for (final s in _existingSessions) {
      final st = s.status.toLowerCase();
      if (st == 'cancelled' || st == 'completed') continue;
      if ((s.doctorId ?? '').trim() != doctorId) continue;
      final otherRaw = s.scheduledAt;
      final otherStart = DateTime.tryParse(otherRaw ?? '')?.toUtc();
      if (otherStart == null) continue;

      // We don't have other session duration from the API, so we protect the selected slot
      // by blocking a symmetric window around existing starts.
      final buffer = Duration(minutes: durationMinutes);
      final otherEndApprox = otherStart.add(buffer);

      final overlaps = startUtc.isBefore(otherEndApprox) && otherStart.isBefore(endUtc);
      if (overlaps) return true;
    }
    return false;
  }

  BookingDto? _bookingForSessionId(String? sessionId) {
    if (sessionId == null || sessionId.trim().isEmpty) return null;
    final s = _existingSessions.where((x) => x.id == sessionId).toList();
    if (s.isEmpty) return null;
    final bookingId = s.first.bookingId;
    final b = _bookings.where((x) => x.id == bookingId).toList();
    return b.isEmpty ? null : b.first;
  }

  List<SessionDto> _schedulableSessions() {
    final byClient = (_clientId == null || _clientId!.trim().isEmpty)
        ? _existingSessions
        : _existingSessions.where((s) => s.clientId == _clientId).toList();

    final list = byClient.where((s) {
      final st = s.status.toLowerCase();
      if (st == 'cancelled' || st == 'completed') return false;
      final hasSchedule = (s.scheduledAt ?? '').trim().isNotEmpty;
      return !hasSchedule;
    }).toList();

    // Keep stable ordering, but prefer unscheduled with doctor unassigned first.
    list.sort((a, b) {
      final aAssigned = (a.doctorId ?? '').trim().isNotEmpty;
      final bAssigned = (b.doctorId ?? '').trim().isNotEmpty;
      if (aAssigned == bAssigned) return 0;
      return aAssigned ? 1 : -1;
    });
    return list;
  }

  List<DoctorDto> _availableSpecialistsForSelection() {
    // Backend enforces doctor availability only for NON-physical sessions.
    final base =
        _sessionTypeUi == _SessionTypeUi.physical ? _specialists : _specialists.where((d) => d.isAvailable).toList();

    if (_scheduledLocal == null) return base;
    final startUtc = _scheduledLocal!.toUtc();
    return base.where((d) {
      return !_overlapsExisting(
        doctorId: d.id,
        startUtc: startUtc,
        durationMinutes: _durationMinutes,
      );
    }).toList();
  }

  void _applySessionDefaults() {
    final b = _bookingForSessionId(_sessionId);
    if (b == null) return;
    final raw = b.sessionType.toLowerCase().trim(); // backend uses audio|video|physical
    final nextType = raw == 'physical' ? _SessionTypeUi.physical : _SessionTypeUi.online;

    final nextVenue = (b.physicalVenue ?? '').toLowerCase().trim();
    final nextLocation = nextVenue == 'office'
        ? _PhysicalLocationUi.clinic
        : (nextVenue == 'home' ? _PhysicalLocationUi.clientAddress : _PhysicalLocationUi.custom);

    setState(() {
      if (!_sessionTypeManuallySet) _sessionTypeUi = nextType;
      _physicalLocationUi = nextLocation;
    });

    _physicalAddress.text = (b.physicalLocationAddress ?? '').trim();
    _physicalLat.text = b.physicalLocationLat?.toString() ?? '';
    _physicalLng.text = b.physicalLocationLng?.toString() ?? '';
    _physicalAccessNotes.text = (b.physicalNotes ?? '').trim();

    if (_autoGenerateLink && _sessionTypeUi == _SessionTypeUi.online && _scheduledLocal != null) {
      _meetingLink.text = _generatedMeetingLink();
    }
  }

  bool _canAttemptSubmit() {
    if (_saving || _loading || _error != null) return false;
    if (_clientId == null || _clientId!.trim().isEmpty) return false;
    if (_sessionId == null || _sessionId!.trim().isEmpty) return false;
    if (_scheduledLocal == null) return false;
    if (_doctorId == null || _doctorId!.trim().isEmpty) return false;
    if (_sessionTypeUi == _SessionTypeUi.online && !_autoGenerateLink && _meetingLink.text.trim().isEmpty) return false;
    if (_sessionTypeUi == _SessionTypeUi.physical && _physicalAddress.text.trim().isEmpty) return false;
    return true;
  }

  String _buildUnifiedNotes() {
    final base = _notes.text.trim();
    if (_sessionTypeUi != _SessionTypeUi.physical) return base;

    final address = _physicalAddress.text.trim();
    final lat = _physicalLat.text.trim();
    final lng = _physicalLng.text.trim();
    final contactName = _physicalContactName.text.trim();
    final contactPhone = _physicalContactPhone.text.trim();
    final accessNotes = _physicalAccessNotes.text.trim();

    final location = switch (_physicalLocationUi) {
      _PhysicalLocationUi.clinic => 'clinic',
      _PhysicalLocationUi.clientAddress => 'client_address',
      _PhysicalLocationUi.custom => 'custom',
    };

    final lines = <String>[
      'PHYSICAL_COORDINATION:',
      'location: $location',
      if (address.isNotEmpty) 'address: $address',
      if (lat.isNotEmpty) 'lat: $lat',
      if (lng.isNotEmpty) 'lng: $lng',
      if (contactName.isNotEmpty) 'contact_name: $contactName',
      if (contactPhone.isNotEmpty) 'contact_phone: $contactPhone',
      if (accessNotes.isNotEmpty) 'notes: $accessNotes',
    ];

    final block = lines.join('\n');
    if (base.isEmpty) return block;
    return '$base\n\n$block';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    setState(() => _submitted = true);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final doctorId = _doctorId!;
    final sessionId = _sessionId!;
    final local = _scheduledLocal!;
    final scheduledAtUtcIso = local.toUtc().toIso8601String();

    final meetingLink = _sessionTypeUi == _SessionTypeUi.online ? _meetingLink.text.trim() : null;

    if (_sessionTypeUi == _SessionTypeUi.online && (meetingLink == null || meetingLink.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting link is required for online sessions.')));
      return;
    }

    final startUtc = DateTime.parse(scheduledAtUtcIso);
    final conflict = _overlapsExisting(doctorId: doctorId, startUtc: startUtc, durationMinutes: _durationMinutes);
    if (conflict) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This specialist is already booked around that time. Choose another slot.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Backend: admin schedules by assigning a doctor to an existing session.
      final assigned = await _api.assignSessionDoctor(
        sessionId: sessionId,
        doctorId: doctorId,
        scheduledAtIso: scheduledAtUtcIso,
        meetingLink: _autoGenerateLink ? null : meetingLink,
      );

      final unifiedNotes = _buildUnifiedNotes().trim();
      final notes = unifiedNotes.isEmpty ? null : unifiedNotes;
      if (notes != null) {
        await _api.patchSession(assigned.id, notes: notes);
      }

      await NotificationService.adminOps(
        title: 'Session scheduled',
        body: 'A ${_sessionTypeUi == _SessionTypeUi.online ? "online" : "physical"} session was scheduled.',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session scheduled.')));
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not schedule session.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not schedule session.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatWhen(DateTime? dt) {
    if (dt == null) return 'Pick date & time';
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final d = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return '$d · $hour12:$min $ampm';
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

  String _shortId(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

  String _sessionPickLabel(SessionDto s) {
    final booking = _bookings.where((b) => b.id == s.bookingId).toList();
    final b = booking.isEmpty ? null : booking.first;
    final rawType = (b?.sessionType ?? '').toLowerCase().trim();
    final typeLabel = rawType.isEmpty ? 'Session' : (rawType == 'physical' ? 'Physical' : 'Online');
    final pref = _formatPreferred(b?.firstPreferredDateUtc);
    return '$typeLabel · $pref · booking …${_shortId(s.bookingId)} · session …${_shortId(s.id)}';
  }

  String _clientLabel(String id) {
    final c = _clients.where((x) => x.id == id).toList();
    if (c.isEmpty) return '—';
    final u = c.first;
    return u.fullName.trim().isEmpty ? u.email : u.fullName;
  }

  String _doctorLabel(String id) {
    final d = _specialists.where((x) => x.id == id).toList();
    if (d.isEmpty) return '—';
    final u = d.first;
    return u.fullName.trim().isEmpty ? u.email : u.fullName;
  }

  @override
  Widget build(BuildContext context) {
    final schedulable = _schedulableSessions();
    final specialistChoices = _availableSpecialistsForSelection();
    final showRequestStep = _clientId != null && _clientId!.trim().isNotEmpty;
    final showScheduleStep = showRequestStep && _sessionId != null && _sessionId!.trim().isNotEmpty;
    final showSpecialistStep = showScheduleStep && _scheduledLocal != null;
    final showMeetingStep = showSpecialistStep && _doctorId != null && _doctorId!.trim().isNotEmpty;
    final isOnline = _sessionTypeUi == _SessionTypeUi.online;
    final isPhysical = _sessionTypeUi == _SessionTypeUi.physical;

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Schedule session', style: TextStyle(fontWeight: FontWeight.w900)),
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
                    autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _Card(
                          title: 'Session details',
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
                                          _scheduledLocal = null;
                                          _doctorId = null;
                                          _meetingLink.text = '';
                                          _notes.text = '';
                                          _sessionTypeUi = _SessionTypeUi.online;
                                          _sessionTypeManuallySet = false;
                                          _physicalLocationUi = _PhysicalLocationUi.clientAddress;
                                          _physicalAddress.text = '';
                                          _physicalLat.text = '';
                                          _physicalLng.text = '';
                                          _physicalContactName.text = '';
                                          _physicalContactPhone.text = '';
                                          _physicalAccessNotes.text = '';
                                          _submitted = false;
                                        });
                                      },
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please select a client.' : null,
                              ),
                            ],
                          ),
                        ),

                        if (showRequestStep) ...[
                          const SizedBox(height: 14),
                          _Card(
                            title: 'Select request',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _sessionId,
                                  decoration: const InputDecoration(labelText: 'Select Request', filled: true),
                                  items: schedulable
                                      .map((s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(_sessionPickLabel(s), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _sessionId = v;
                                            _scheduledLocal = null;
                                            _doctorId = null;
                                            _meetingLink.text = '';
                                            _notes.text = '';
                                            _sessionTypeManuallySet = false;
                                            _physicalContactName.text = '';
                                            _physicalContactPhone.text = '';
                                          });
                                          _applySessionDefaults();
                                        },
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please select a request.' : null,
                                ),
                                if (schedulable.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6, left: 12),
                                    child: Text(
                                      'No pending requests for this client.',
                                      style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                const Text('Session type', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const Text('Online Session', style: TextStyle(fontWeight: FontWeight.w900)),
                                        selected: _sessionTypeUi == _SessionTypeUi.online,
                                        onSelected: _saving
                                            ? null
                                            : (v) {
                                                if (!v) return;
                                                setState(() {
                                                  _sessionTypeUi = _SessionTypeUi.online;
                                                  _sessionTypeManuallySet = true;
                                                  _autoGenerateLink = true;
                                                  if (_scheduledLocal != null) _meetingLink.text = _generatedMeetingLink();
                                                });
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ChoiceChip(
                                        label: const Text('Physical Session', style: TextStyle(fontWeight: FontWeight.w900)),
                                        selected: _sessionTypeUi == _SessionTypeUi.physical,
                                        onSelected: _saving
                                            ? null
                                            : (v) {
                                                if (!v) return;
                                                setState(() {
                                                  _sessionTypeUi = _SessionTypeUi.physical;
                                                  _sessionTypeManuallySet = true;
                                                  _meetingLink.text = '';
                                                });
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  value: _durationMinutes,
                                  decoration: const InputDecoration(labelText: 'Session Duration', filled: true),
                                  items: const [30, 45, 60, 90]
                                      .map((m) => DropdownMenuItem(value: m, child: Text('$m minutes')))
                                      .toList(),
                                  onChanged: _saving
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _durationMinutes = v ?? 60;
                                            _doctorId = null;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (showScheduleStep) ...[
                          const SizedBox(height: 14),
                          _Card(
                            title: 'Schedule',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                InkWell(
                                  onTap: _saving ? null : _pickDateTime,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Date & time',
                                      filled: true,
                                      errorText: (_submitted && _scheduledLocal == null) ? 'Please pick date & time.' : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(_formatWhen(_scheduledLocal), style: const TextStyle(fontWeight: FontWeight.w800)),
                                        ),
                                        const Icon(Icons.schedule_rounded, color: SmartAfyaPalette.primaryBlue),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _doctorId,
                                  decoration: const InputDecoration(labelText: 'Available Specialist', filled: true),
                                  items: specialistChoices
                                      .map((d) => DropdownMenuItem(value: d.id, child: Text(d.fullName.isEmpty ? d.email : d.fullName)))
                                      .toList(),
                                  onChanged: _saving || !showSpecialistStep ? null : (v) => setState(() => _doctorId = v),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please select a specialist.' : null,
                                ),
                                if (_scheduledLocal != null && specialistChoices.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6, left: 12),
                                    child: Text(
                                      'No specialists available for the selected time.',
                                      style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        if (isPhysical && showScheduleStep) ...[
                          const SizedBox(height: 14),
                          _Card(
                            title: 'Physical coordination',
                            child: _PhysicalCoordinationSection(
                              enabled: !_saving,
                              locationUi: _physicalLocationUi,
                              onLocationChanged: (v) => setState(() => _physicalLocationUi = v),
                              address: _physicalAddress,
                              lat: _physicalLat,
                              lng: _physicalLng,
                              contactName: _physicalContactName,
                              contactPhone: _physicalContactPhone,
                              accessNotes: _physicalAccessNotes,
                              submitted: _submitted,
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        _Card(
                          title: 'Notes',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _notes,
                                decoration: const InputDecoration(
                                  labelText: 'Notes (optional)',
                                  helperText: 'Optional instructions for the client or specialist',
                                  filled: true,
                                ),
                                enabled: !_saving,
                                minLines: 4,
                                maxLines: 8,
                              ),
                            ],
                          ),
                        ),

                        if (showMeetingStep) ...[
                          const SizedBox(height: 14),
                          if (isOnline) ...[
                            _Card(
                              title: 'Confirmation · Meeting link',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: _autoGenerateLink,
                                    onChanged: _saving
                                        ? null
                                        : (v) {
                                            setState(() => _autoGenerateLink = v);
                                            if (v && _scheduledLocal != null) {
                                              _meetingLink.text = _generatedMeetingLink();
                                            }
                                          },
                                    title: const Text('Auto-generate meeting link', style: TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: const Text('Recommended for fast scheduling.'),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_autoGenerateLink) ...[
                                    DropdownButtonFormField<String>(
                                      value: _meetingPlatform,
                                      decoration: const InputDecoration(labelText: 'Platform', filled: true),
                                      items: const [
                                        DropdownMenuItem(value: 'google_meet', child: Text('Google Meet')),
                                        DropdownMenuItem(value: 'zoom', child: Text('Zoom')),
                                      ],
                                      onChanged: _saving
                                          ? null
                                          : (v) {
                                              setState(() => _meetingPlatform = v ?? 'google_meet');
                                              if (_scheduledLocal != null) {
                                                _meetingLink.text = _generatedMeetingLink();
                                              }
                                            },
                                    ),
                                    const SizedBox(height: 10),
                                    InputDecorator(
                                      decoration: const InputDecoration(labelText: 'Generated meeting link', filled: true),
                                      child: SelectableText(
                                        _scheduledLocal == null ? 'Pick date & time to generate link.' : _meetingLink.text,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ] else ...[
                                    TextFormField(
                                      controller: _meetingLink,
                                      decoration: const InputDecoration(
                                        labelText: 'Meeting link',
                                        hintText: 'Paste Zoom / Google Meet link…',
                                        filled: true,
                                      ),
                                      enabled: !_saving,
                                      validator: (v) {
                                        if (!isOnline) return null;
                                        if (_autoGenerateLink) return null;
                                        final s = (v ?? '').trim();
                                        if (s.isEmpty) return 'Meeting link is required.';
                                        return null;
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _Card(
                            title: 'Review summary',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SummaryRow(label: 'Client', value: _clientId == null ? '—' : _clientLabel(_clientId!)),
                                _SummaryRow(label: 'Request', value: _sessionId == null ? '—' : 'Session …${_shortId(_sessionId!)}'),
                                _SummaryRow(label: 'Specialist', value: _doctorId == null ? '—' : _doctorLabel(_doctorId!)),
                                _SummaryRow(label: 'Date & time', value: _formatWhen(_scheduledLocal)),
                                _SummaryRow(label: 'Duration', value: '$_durationMinutes minutes'),
                                _SummaryRow(
                                  label: 'Meeting',
                                  value: _sessionTypeUi == _SessionTypeUi.physical
                                      ? 'Physical session'
                                      : (_autoGenerateLink ? 'Auto-generated ($_meetingPlatform)' : 'Manual link'),
                                ),
                                if (_sessionTypeUi != _SessionTypeUi.physical)
                                  _SummaryRow(label: 'Meeting link', value: _meetingLink.text.trim().isEmpty ? '—' : _meetingLink.text.trim()),
                                if (_sessionTypeUi == _SessionTypeUi.physical) ...[
                                  _SummaryRow(
                                    label: 'Location',
                                    value: _physicalAddress.text.trim().isEmpty ? '—' : _physicalAddress.text.trim(),
                                  ),
                                  _SummaryRow(
                                    label: 'Contact',
                                    value: (_physicalContactName.text.trim().isEmpty && _physicalContactPhone.text.trim().isEmpty)
                                        ? '—'
                                        : '${_physicalContactName.text.trim()} ${_physicalContactPhone.text.trim()}'.trim(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE4EEF7))),
          ),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _canAttemptSubmit() ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: SmartAfyaPalette.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(_saving ? 'Scheduling…' : 'Schedule Session', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _PhysicalCoordinationSection extends StatefulWidget {
  const _PhysicalCoordinationSection({
    required this.enabled,
    required this.locationUi,
    required this.onLocationChanged,
    required this.address,
    required this.lat,
    required this.lng,
    required this.contactName,
    required this.contactPhone,
    required this.accessNotes,
    required this.submitted,
  });

  final bool enabled;
  final _PhysicalLocationUi locationUi;
  final void Function(_PhysicalLocationUi) onLocationChanged;
  final TextEditingController address;
  final TextEditingController lat;
  final TextEditingController lng;
  final TextEditingController contactName;
  final TextEditingController contactPhone;
  final TextEditingController accessNotes;
  final bool submitted;

  @override
  State<_PhysicalCoordinationSection> createState() => _PhysicalCoordinationSectionState();
}

class _PhysicalCoordinationSectionState extends State<_PhysicalCoordinationSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final addressEmpty = widget.address.text.trim().isEmpty;
    final showError = widget.submitted && addressEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          title: const Text('Location & contact', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(
            widget.address.text.trim().isEmpty ? 'Add address and optional coordinates' : widget.address.text.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, color: SmartAfyaPalette.mutedText),
          ),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Clinic', style: TextStyle(fontWeight: FontWeight.w900)),
                    selected: widget.locationUi == _PhysicalLocationUi.clinic,
                    onSelected: !widget.enabled ? null : (v) => v ? widget.onLocationChanged(_PhysicalLocationUi.clinic) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Client address', style: TextStyle(fontWeight: FontWeight.w900)),
                    selected: widget.locationUi == _PhysicalLocationUi.clientAddress,
                    onSelected: !widget.enabled ? null : (v) => v ? widget.onLocationChanged(_PhysicalLocationUi.clientAddress) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Custom', style: TextStyle(fontWeight: FontWeight.w900)),
                    selected: widget.locationUi == _PhysicalLocationUi.custom,
                    onSelected: !widget.enabled ? null : (v) => v ? widget.onLocationChanged(_PhysicalLocationUi.custom) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.address,
              enabled: widget.enabled,
              decoration: InputDecoration(
                labelText: 'Address / location',
                hintText: 'Clinic name, street, landmark…',
                filled: true,
                errorText: showError ? 'Address is required for physical sessions.' : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.lat,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitude (optional)', filled: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: widget.lng,
                    enabled: widget.enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitude (optional)', filled: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.contactName,
                    enabled: widget.enabled,
                    decoration: const InputDecoration(labelText: 'Contact person (optional)', filled: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: widget.contactPhone,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone number (optional)', filled: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.accessNotes,
              enabled: widget.enabled,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Directions / access notes (optional)',
                hintText: 'Gate code, reception, landmarks, parking…',
                filled: true,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ],
    );
  }
}


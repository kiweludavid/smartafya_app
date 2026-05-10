import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'admin_client_description_screen.dart';
import 'app_palette.dart';

enum _RequestsFilter { all, pending, assigned, completed }

extension on _RequestsFilter {
  String get label {
    switch (this) {
      case _RequestsFilter.all:
        return 'All Requests';
      case _RequestsFilter.pending:
        return 'Pending';
      case _RequestsFilter.assigned:
        return 'Assigned';
      case _RequestsFilter.completed:
        return 'Completed';
    }
  }
}

String _tail(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

String _fmtDate(DateTime dt) {
  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class _StatusColors {
  const _StatusColors(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({
    super.key,
    this.initialFilterIndex = 0,
  });

  /// 0=All Requests, 1=Pending, 2=Assigned, 3=Completed
  final int initialFilterIndex;

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  static const _hairline = Color(0xFFE4EEF7);
  static const _shadow = [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))];

  final _api = ApiService();
  bool _loading = true;
  String? _error;

  List<BookingDto> _bookings = [];
  Map<String, SessionDto> _sessionByBookingId = {};
  List<DoctorDto> _doctors = [];
  final Map<String, String> _nameByUserId = {};

  int _filterIndex = 0;
  String? _busySessionId;

  @override
  void initState() {
    super.initState();
    _filterIndex = widget.initialFilterIndex.clamp(0, 3);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchAllBookings(),
        _api.fetchSessions(),
        _api.fetchDoctors(availableOnly: false),
        _api.fetchAllUsersForAdmin(),
      ]);
      final bookings = results[0] as List<BookingDto>;
      final sessions = results[1] as List<SessionDto>;
      final doctors = results[2] as List<DoctorDto>;
      final users = results[3] as List<AdminUserDto>;

      final sByB = <String, SessionDto>{};
      for (final s in sessions) {
        sByB[s.bookingId] = s;
      }

      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _sessionByBookingId = sByB;
        _doctors = doctors;
        _nameByUserId
          ..clear()
          ..addEntries(users.map((u) {
            final name = u.fullName.trim().isEmpty ? u.email : u.fullName.trim();
            return MapEntry(u.id, name);
          }));
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load requests.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load requests.';
      });
    }
  }

  String _clientName(String clientId) {
    final name = _nameByUserId[clientId];
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'Client …${_tail(clientId)}';
  }

  List<_RequestRow> get _rows {
    final rows = <_RequestRow>[];
    for (final b in _bookings) {
      final s = _sessionByBookingId[b.id];
      if (s == null) continue;
      rows.add(_RequestRow(booking: b, session: s));
    }
    rows.sort((a, b) {
      final da = a.booking.createdAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.booking.createdAtUtc ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return rows;
  }

  List<_RequestRow> get _filteredRows {
    final f = _RequestsFilter.values[_filterIndex];
    if (f == _RequestsFilter.all) return _rows;
    return _rows.where((r) => _requestStatusFor(booking: r.booking, session: r.session) == f).toList();
  }

  Future<void> _assignSpecialistFlow({required BookingDto booking, required SessionDto session}) async {
    if (!booking.consentGiven) {
      final action = await _showConsentMissingDialog(context);
      if (action == _ConsentAction.decline) {
        await _declineRequest(session);
      }
      return;
    }

    final picked = await showModalBottomSheet<_AssignPick>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => _AssignSheet(doctors: _doctors),
    );
    if (picked == null) return;

    try {
      setState(() => _busySessionId = session.id);
      final updated = await _api.assignSessionDoctor(
        sessionId: session.id,
        doctorId: picked.doctorId,
        scheduledAtIso: picked.scheduledAtUtcIso,
      );
      if (!mounted) return;
      setState(() {
        _sessionByBookingId[booking.id] = updated;
        _busySessionId = null;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Specialist assigned.')));
      }
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Assignment failed.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment failed.')));
    }
  }

  _StatusColors _statusColors(_RequestsFilter status) {
    switch (status) {
      case _RequestsFilter.pending:
        return const _StatusColors(Color(0xFFFFF4E5), Color(0xFFB8860B)); // orange
      case _RequestsFilter.assigned:
        return const _StatusColors(Color(0xFFEAF2FF), SmartAfyaPalette.primaryBlue); // blue
      case _RequestsFilter.completed:
        return const _StatusColors(Color(0xFFE8F5E9), SmartAfyaPalette.primaryGreen); // green
      case _RequestsFilter.all:
        return const _StatusColors(SmartAfyaPalette.softBlue, SmartAfyaPalette.primaryBlue);
    }
  }

  Future<void> _declineRequest(SessionDto session) async {
    try {
      setState(() => _busySessionId = session.id);
      await _api.patchSession(session.id, status: 'cancelled');
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined (session cancelled).')));
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not decline request.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Requests', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _Segmented(
              index: _filterIndex,
              onChanged: (i) => setState(() => _filterIndex = i),
              labels: _RequestsFilter.values.map((e) => e.label).toList(),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: SmartAfyaPalette.primaryBlue,
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue))
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: _load,
                                style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : _RequestsCardsList(
                      rows: _filteredRows,
                      busySessionId: _busySessionId,
                      filter: _RequestsFilter.values[_filterIndex],
                      onRefresh: _load,
                      onViewAll: () => setState(() => _filterIndex = 0),
                      clientName: _clientName,
                      onViewDetails: (r) async {
                        final status = _requestStatusFor(booking: r.booking, session: r.session);
                        final colors = _statusColors(status);
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AdminClientDescriptionScreen(
                              booking: r.booking,
                              session: r.session,
                              clientName: _clientName(r.booking.clientId),
                              statusLabel: _requestStatusLabel(booking: r.booking, session: r.session),
                              statusBg: colors.bg,
                              statusFg: colors.fg,
                              previousSessionsCount: _existingSessionsCountForClient(r.booking.clientId, currentSessionId: r.session.id),
                              onAssignSpecialist: () => _assignSpecialistFlow(booking: r.booking, session: r.session),
                            ),
                          ),
                        );
                        if (!context.mounted) return;
                        await _load();
                      },
                      onAssign: (r) => _assignSpecialistFlow(booking: r.booking, session: r.session),
                    ),
        ),
      ),
    );
  }

  int _existingSessionsCountForClient(String clientId, {required String currentSessionId}) {
    final sessions = _sessionByBookingId.values.where((s) => s.clientId == clientId && s.id != currentSessionId).toList();
    return sessions.length;
  }
}

class _RequestRow {
  const _RequestRow({required this.booking, required this.session});
  final BookingDto booking;
  final SessionDto session;
}

_RequestsFilter _requestStatusFor({required BookingDto booking, required SessionDto? session}) {
  final st = (session?.status ?? '').toLowerCase().trim();
  if (st == 'completed') return _RequestsFilter.completed;
  final assigned = (session?.doctorId ?? '').trim().isNotEmpty;
  if (assigned) return _RequestsFilter.assigned;
  return _RequestsFilter.pending;
}

String _requestStatusLabel({required BookingDto booking, required SessionDto? session}) {
  final f = _requestStatusFor(booking: booking, session: session);
  switch (f) {
    case _RequestsFilter.pending:
      return 'Pending';
    case _RequestsFilter.assigned:
      return 'Assigned';
    case _RequestsFilter.completed:
      return 'Completed';
    case _RequestsFilter.all:
      return '—';
  }
}

class _RequestsCardsList extends StatelessWidget {
  const _RequestsCardsList({
    required this.rows,
    required this.busySessionId,
    required this.filter,
    required this.onRefresh,
    required this.onViewAll,
    required this.clientName,
    required this.onViewDetails,
    required this.onAssign,
  });

  final List<_RequestRow> rows;
  final String? busySessionId;
  final _RequestsFilter filter;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewAll;
  final String Function(String clientId) clientName;
  final void Function(_RequestRow row) onViewDetails;
  final Future<void> Function(_RequestRow row) onAssign;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      final isPending = filter == _RequestsFilter.pending;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
        children: [
          Center(
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: SmartAfyaPalette.softBlue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.inbox_outlined, color: SmartAfyaPalette.primaryBlue, size: 34),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              isPending ? 'No pending requests right now' : 'No requests found',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 16),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              isPending ? 'New consultation requests will appear here' : 'Try a different filter or refresh',
              textAlign: TextAlign.center,
              style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async => onRefresh(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onViewAll,
                  style: FilledButton.styleFrom(
                    backgroundColor: SmartAfyaPalette.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('View All Requests', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: rows.length,
      separatorBuilder: (_, i) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final r = rows[i];
        final saving = busySessionId == r.session.id;
        return _RequestCard(
          row: r,
          saving: saving,
          clientName: clientName(r.booking.clientId),
          onViewDetails: () => onViewDetails(r),
          onAssign: () => onAssign(r),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.row,
    required this.saving,
    required this.clientName,
    required this.onViewDetails,
    required this.onAssign,
  });

  final _RequestRow row;
  final bool saving;
  final String clientName;
  final VoidCallback onViewDetails;
  final Future<void> Function() onAssign;

  @override
  Widget build(BuildContext context) {
    final b = row.booking;
    final s = row.session;
    final created = b.createdAtUtc?.toLocal();
    final status = _requestStatusFor(booking: b, session: s);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _AdminRequestsScreenState._hairline),
            boxShadow: _AdminRequestsScreenState._shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          created == null ? 'Date submitted: —' : 'Date submitted: ${_fmtDate(created)}',
                          style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onViewDetails,
                      style: FilledButton.styleFrom(
                        backgroundColor: SmartAfyaPalette.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Open Request', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: (saving || status == _RequestsFilter.completed) ? null : () async => onAssign(),
                      style: FilledButton.styleFrom(
                        backgroundColor: SmartAfyaPalette.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Assign Specialist', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final _RequestsFilter status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;
    switch (status) {
      case _RequestsFilter.pending:
        bg = const Color(0xFFFFF4E5);
        fg = const Color(0xFFB8860B);
        label = 'Pending';
      case _RequestsFilter.assigned:
        bg = const Color(0xFFEAF2FF);
        fg = SmartAfyaPalette.primaryBlue;
        label = 'Assigned';
      case _RequestsFilter.completed:
        bg = const Color(0xFFE8F5E9);
        fg = SmartAfyaPalette.primaryGreen;
        label = 'Completed';
      case _RequestsFilter.all:
        bg = SmartAfyaPalette.softBlue;
        fg = SmartAfyaPalette.primaryBlue;
        label = '—';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: fg)),
    );
  }
}

enum _ConsentAction { decline, returnToClient }

Future<_ConsentAction?> _showConsentMissingDialog(BuildContext context) {
  return showDialog<_ConsentAction>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Consent not provided'),
        content: const Text('Consent not provided. You can decline or return request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _ConsentAction.returnToClient),
            child: const Text('Return to Client'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _ConsentAction.decline),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318), foregroundColor: Colors.white),
            child: const Text('Decline Request'),
          ),
        ],
      );
    },
  );
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.index,
    required this.onChanged,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: i == index ? SmartAfyaPalette.primaryBlue.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          color: i == index ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.mutedText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (i != labels.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _AssignPick {
  const _AssignPick({required this.doctorId, required this.scheduledAtUtcIso});
  final String doctorId;
  final String scheduledAtUtcIso;
}

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({required this.doctors});
  final List<DoctorDto> doctors;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  String? _doctorId;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    _doctorId = widget.doctors.isNotEmpty ? widget.doctors.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.doctors]..sort((a, b) {
      if (a.isAvailable == b.isAvailable) return 0;
      return a.isAvailable ? -1 : 1;
    });

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Assign Specialist', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'Pick a specialist and schedule the session. Specialists are sorted by availability.',
              style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.35),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _doctorId,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFFF7FAFD),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
              ),
              items: sorted
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '${d.fullName} · ${d.specialistLabel}${d.isAvailable ? '' : ' (busy)'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _doctorId = v),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: _date,
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text('Date: ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
              icon: const Icon(Icons.schedule_rounded),
              label: Text('Time: ${_time.format(context)}'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (_doctorId ?? '').trim().isEmpty
                  ? null
                  : () {
                      final local = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
                      final utcIso = local.toUtc().toIso8601String();
                      Navigator.pop(context, _AssignPick(doctorId: _doctorId!, scheduledAtUtcIso: utcIso));
                    },
              style: FilledButton.styleFrom(
                backgroundColor: SmartAfyaPalette.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Assign & Schedule', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}


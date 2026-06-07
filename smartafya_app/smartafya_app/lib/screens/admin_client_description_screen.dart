import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import 'admin_schedule_session_screen.dart';
import 'app_palette.dart';
import 'chat_list_screen.dart';

enum _UrgencyLevel { low, medium, high }

_UrgencyLevel _urgencyFromText(String text) {
  final s = text.toLowerCase();
  const high = [
    'suicide',
    'suicidal',
    'kill myself',
    'self-harm',
    'self harm',
    'harm myself',
    'hurt myself',
    'panic attack',
  ];
  if (high.any(s.contains)) return _UrgencyLevel.high;
  const medium = ['depression', 'depressed', 'anxiety', 'ptsd', 'trauma', 'addiction', 'abuse', 'violence'];
  if (medium.any(s.contains)) return _UrgencyLevel.medium;
  return _UrgencyLevel.low;
}

String _fmtDate(DateTime dt) {
  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class AdminClientDescriptionScreen extends StatefulWidget {
  const AdminClientDescriptionScreen({
    super.key,
    required this.booking,
    required this.session,
    required this.clientName,
    required this.statusLabel,
    required this.statusBg,
    required this.statusFg,
    required this.onAssignSpecialist,
    required this.previousSessionsCount,
  });

  final BookingDto booking;
  final SessionDto session;
  final String clientName;
  final String statusLabel;
  final Color statusBg;
  final Color statusFg;
  final Future<void> Function() onAssignSpecialist;
  final int previousSessionsCount;

  @override
  State<AdminClientDescriptionScreen> createState() => _AdminClientDescriptionScreenState();
}

class _AdminClientDescriptionScreenState extends State<AdminClientDescriptionScreen> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final s = widget.session;
    final desc = (b.mentalHealthDescription ?? '').trim();
    final created = b.createdAtUtc?.toLocal();
    final venue = (b.sessionType).toLowerCase().trim() == 'physical' ? 'Physical' : 'Online';
    final urgency = _urgencyFromText(desc);
    final summary = _issueSummary(desc);
    final preferredDates = _parsePreferredDates(b.preferredDatesRaw);
    final hasPreferredDates = preferredDates.isNotEmpty;
    final isPhysical = venue == 'Physical';
    final locationText = (b.physicalLocationAddress ?? '').trim();
    final physicalNotes = (b.physicalNotes ?? '').trim();

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Request', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.clientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: SmartAfyaPalette.deepText,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Request …${_tail(b.id)}',
                              style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(label: widget.statusLabel, bg: widget.statusBg, fg: widget.statusFg),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetaChip(
                        icon: Icons.calendar_month_rounded,
                        label: created == null ? 'Submitted: —' : 'Submitted: ${_fmtDate(created)}',
                      ),
                      _MetaChip(
                        icon: venue == 'Physical' ? Icons.location_on_rounded : Icons.videocam_rounded,
                        label: 'Session: $venue',
                      ),
                      _MetaChip(
                        icon: Icons.priority_high_rounded,
                        label: 'Urgency: ${_urgencyLabel(urgency)}',
                        bg: _urgencyColor(urgency),
                      ),
                      _MetaChip(
                        icon: Icons.history_rounded,
                        label: 'Previous: ${widget.previousSessionsCount}',
                      ),
                      if (b.consentGiven)
                        const _MetaChip(
                          icon: Icons.verified_user_rounded,
                          label: 'Consent: Yes',
                          bg: Color(0xFFEAF7EE),
                        )
                      else
                        const _MetaChip(
                          icon: Icons.warning_rounded,
                          label: 'Consent: No',
                          bg: Color(0xFFFFE7E7),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              title: 'Issue summary',
              accent: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SmartAfyaPalette.primaryBlue,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary.isEmpty ? '—' : summary,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w800, height: 1.35, fontSize: 14.2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              title: 'Full description',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          desc.isEmpty ? '—' : desc,
                          maxLines: _expanded ? 999 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.45),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: desc.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(ClipboardData(text: desc));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Description copied.')));
                                }
                              },
                        tooltip: 'Copy',
                        icon: const Icon(Icons.copy_rounded),
                        color: SmartAfyaPalette.mutedText,
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty && desc.length > 220) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        child: Text(_expanded ? 'Show less' : 'Read more', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Card(
              title: 'Preferences',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 18, color: SmartAfyaPalette.primaryBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasPreferredDates ? 'Preferred dates' : 'Preferred dates: —',
                          style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  if (hasPreferredDates) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: preferredDates.map((d) => _Pill(text: d)).toList(),
                    ),
                  ],
                  if (isPhysical) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 18, color: SmartAfyaPalette.primaryBlue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Physical location',
                            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      locationText.isEmpty ? '—' : locationText,
                      style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                    if (physicalNotes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Notes', style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        physicalNotes,
                        style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute<bool>(
                            builder: (_) => AdminScheduleSessionScreen(
                              initialClientId: b.clientId,
                              initialSessionId: s.id,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Schedule Session', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async => widget.onAssignSpecialist(),
                      style: FilledButton.styleFrom(
                        backgroundColor: SmartAfyaPalette.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Assign Specialist', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const ChatListScreen()));
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Request more info', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _urgencyLabel(_UrgencyLevel u) {
    switch (u) {
      case _UrgencyLevel.high:
        return 'High';
      case _UrgencyLevel.medium:
        return 'Medium';
      case _UrgencyLevel.low:
        return 'Low';
    }
  }

  static String _issueSummary(String desc) {
    final s = desc.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return '';
    final parts = s.split(RegExp(r'(?<=[\.\!\?])\s+'));
    final first = parts.isEmpty ? s : parts.first.trim();
    if (first.length >= 60) return _cap(first, 240);
    if (parts.length >= 2) {
      final two = '${parts[0].trim()} ${parts[1].trim()}'.trim();
      return _cap(two, 240);
    }
    return _cap(s, 240);
  }

  static String _cap(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max).trimRight()}…';
  }

  static Color _urgencyColor(_UrgencyLevel u) {
    switch (u) {
      case _UrgencyLevel.high:
        return const Color(0xFFFFE7E7);
      case _UrgencyLevel.medium:
        return const Color(0xFFFFF3D6);
      case _UrgencyLevel.low:
        return const Color(0xFFEAF7EE);
    }
  }

  static List<String> _parsePreferredDates(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.title, this.accent = false});

  final String? title;
  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? const Color(0xFFF7FAFD) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEF7)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: fg)),
    );
  }
}

String _tail(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.bg});
  final IconData icon;
  final String label;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: SmartAfyaPalette.primaryBlue),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

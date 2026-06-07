import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

class AdminSessionsScreen extends StatefulWidget {
  const AdminSessionsScreen({
    super.key,
  });

  @override
  State<AdminSessionsScreen> createState() => _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends State<AdminSessionsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<SessionDto> _sessions = [];
  String? _savingSessionId;
  int _filterIndex = 0; // 0 all, 1 scheduled

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _api.fetchSessions();
      if (!mounted) return;
      sessions.sort((a, b) => _cmpSchedule(a.scheduledAt, b.scheduledAt));
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load sessions.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load sessions.';
      });
    }
  }

  int _cmpSchedule(String? a, String? b) {
    final da = DateTime.tryParse(a ?? '')?.toLocal();
    final db = DateTime.tryParse(b ?? '')?.toLocal();
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterIndex == 1
        ? _sessions.where((s) => s.status.toLowerCase() == 'scheduled').toList()
        : _sessions;
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Sessions', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _Segmented(
              index: _filterIndex,
              onChanged: (i) => setState(() => _filterIndex = i),
              labels: const ['All', 'Scheduled'],
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
                  : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'No sessions found.',
                                style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, i) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final s = filtered[i];
                            final st = s.status.toLowerCase();
                            final when = _shortWhen(s.scheduledAt);
                            final hasLink = (s.meetingLink ?? '').trim().isNotEmpty;
                            final saving = _savingSessionId == s.id;
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
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: SmartAfyaPalette.softBlue,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.event_note_outlined, color: SmartAfyaPalette.primaryBlue),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Session …${_tail(s.id)}',
                                              style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '$when · ${st.isEmpty ? '—' : st}',
                                              style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: st == 'scheduled'
                                              ? SmartAfyaPalette.primaryGreen.withValues(alpha: 0.12)
                                              : SmartAfyaPalette.softBlue,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          st.isEmpty ? '—' : st,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            color: st == 'scheduled' ? SmartAfyaPalette.primaryGreen : SmartAfyaPalette.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _MeetingLinkCard(
                                    saving: saving,
                                    hasLink: hasLink,
                                    link: (s.meetingLink ?? '').trim(),
                                    onEdit: () async => _openMeetingLinkEditor(s),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }

  static String _tail(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

  static String _shortWhen(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return 'To be scheduled';
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} · $hour12:$min $ampm';
  }

  Future<void> _openMeetingLinkEditor(SessionDto session) async {
    final c = TextEditingController(text: (session.meetingLink ?? '').trim());
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Meeting link · …${_tail(session.id)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: SmartAfyaPalette.deepText),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c,
                  decoration: InputDecoration(
                    hintText: 'Paste Zoom or Google Meet link',
                    filled: true,
                    fillColor: const Color(0xFFF7FAFD),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: SmartAfyaPalette.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved != true) {
      c.dispose();
      return;
    }

    final link = c.text.trim();
    c.dispose();

    setState(() => _savingSessionId = session.id);
    try {
      final updated = await _api.patchSession(session.id, meetingLink: link.isEmpty ? null : link);
      if (!mounted) return;
      setState(() {
        _sessions = _sessions.map((x) => x.id == updated.id ? updated : x).toList();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting link saved.')));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageFromDioException(e) ?? 'Could not save meeting link.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save meeting link.')));
    } finally {
      if (mounted) setState(() => _savingSessionId = null);
    }
  }
}

class _MeetingLinkCard extends StatelessWidget {
  const _MeetingLinkCard({
    required this.saving,
    required this.hasLink,
    required this.link,
    required this.onEdit,
  });

  final bool saving;
  final bool hasLink;
  final String link;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EEF7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SmartAfyaPalette.softBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.link_outlined, color: SmartAfyaPalette.primaryBlue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Meeting link',
                        style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasLink ? SmartAfyaPalette.primaryGreen.withValues(alpha: 0.12) : SmartAfyaPalette.softBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasLink ? 'Ready' : 'Missing',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: hasLink ? SmartAfyaPalette.primaryGreen : SmartAfyaPalette.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hasLink ? link : 'Add a Zoom / Google Meet link for online sessions.',
                  maxLines: hasLink ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700, height: 1.25),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: saving ? null : () async => onEdit(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(
                          hasLink ? 'Edit link' : 'Add link',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    if (hasLink) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 36,
                        child: FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  await Clipboard.setData(ClipboardData(text: link));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting link copied.')));
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: SmartAfyaPalette.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('Copy', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Minimal segmented control matching AdminRequestsScreen behavior.
// Local-only widget to avoid introducing new shared components.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.index,
    required this.onChanged,
    required this.labels,
  });

  final int index;
  final void Function(int) onChanged;
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
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? SmartAfyaPalette.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : SmartAfyaPalette.mutedText,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}


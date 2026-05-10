import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'admin_feedback_screen.dart';
import 'app_palette.dart';

/// Admin: view-only reports extracted from session notes.
/// Permission rule: no edit/delete actions are exposed here.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<SessionDto> _sessions = [];

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
      final withReports = sessions.where((s) => (s.notes ?? '').contains('CONSULTATION_REPORT:')).toList();
      withReports.sort((a, b) {
        final da = DateTime.tryParse(a.scheduledAt ?? '')?.toLocal();
        final db = DateTime.tryParse(b.scheduledAt ?? '')?.toLocal();
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      if (!mounted) return;
      setState(() {
        _sessions = withReports;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load reports.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load reports.';
      });
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
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Client feedback',
            icon: const Icon(Icons.reviews_outlined),
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const AdminFeedbackScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
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
                  : _sessions.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'No reports submitted yet.',
                                style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _sessions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final s = _sessions[i];
                            return _ReportTile(
                              session: s,
                              onOpen: () => _openReport(context, s),
                            );
                          },
                        ),
        ),
      ),
    );
  }

  void _openReport(BuildContext context, SessionDto session) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        final notes = (session.notes ?? '').trim();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Report · Session …${_tail(session.id)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  _shortWhen(session.scheduledAt),
                  style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4EEF7)),
                  ),
                  child: SelectableText(
                    notes.isEmpty ? '—' : notes,
                    style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: SmartAfyaPalette.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _tail(String id) => id.length <= 6 ? id : id.substring(id.length - 6);

  static String _shortWhen(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return 'Time TBD';
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} · $hour12:$min $ampm';
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.session, required this.onOpen});

  final SessionDto session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hasFollowUp = (session.notes ?? '').contains('FOLLOW_UP_REQUESTED: true') ||
        (session.notes ?? '').contains('FOLLOW_UP_REQUESTED:true');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EEF7)),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SmartAfyaPalette.softBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.article_outlined, color: SmartAfyaPalette.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session …${_AdminReportsScreenState._tail(session.id)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _AdminReportsScreenState._shortWhen(session.scheduledAt),
                      style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (hasFollowUp)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Follow-up',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFFB8860B)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: SmartAfyaPalette.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'View only',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: SmartAfyaPalette.primaryGreen),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


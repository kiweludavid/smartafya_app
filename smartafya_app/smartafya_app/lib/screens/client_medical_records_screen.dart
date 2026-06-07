import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'app_palette.dart';

/// Client-facing medical records: shows completed sessions that have a
/// consultation report embedded in `SessionDto.notes`.
class ClientMedicalRecordsScreen extends StatefulWidget {
  const ClientMedicalRecordsScreen({super.key});

  @override
  State<ClientMedicalRecordsScreen> createState() => _ClientMedicalRecordsScreenState();
}

class _ClientMedicalRecordsScreenState extends State<ClientMedicalRecordsScreen> {
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
      final me = await _api.fetchCurrentUser().timeout(const Duration(seconds: 8));
      final sessions = await _api.fetchSessions().timeout(const Duration(seconds: 8));
      final mine = sessions.where((s) => s.clientId == me.id).toList();
      final records = mine.where((s) {
        final st = (s.status).toLowerCase().trim();
        if (st != 'completed') return false;
        final notes = (s.notes ?? '');
        return notes.contains('CONSULTATION_REPORT:');
      }).toList()
        ..sort((a, b) => (b.scheduledAt ?? '').compareTo(a.scheduledAt ?? ''));
      if (!mounted) return;
      setState(() {
        _sessions = records;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Could not load medical records.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load medical records.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Medical Records', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
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
                      padding: const EdgeInsets.all(20),
                      children: [
                        const SizedBox(height: 40),
                        Center(child: Text(_error!, textAlign: TextAlign.center)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : _sessions.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          children: const [
                            SizedBox(height: 60),
                            Center(child: Text('No medical records yet.')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          itemCount: _sessions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final s = _sessions[i];
                            final when = (s.scheduledAt ?? '—').trim();
                            final report = _extractReportText(s.notes);
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE4EEF7)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Consultation report',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: SmartAfyaPalette.deepText,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'When: $when',
                                    style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    report,
                                    style: const TextStyle(color: SmartAfyaPalette.deepText, height: 1.35, fontWeight: FontWeight.w600),
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

  static String _extractReportText(String? notes) {
    final s = (notes ?? '').trim();
    final idx = s.indexOf('CONSULTATION_REPORT:');
    if (idx < 0) return '—';
    final out = s.substring(idx).trim();
    // Avoid overly long blocks on first view.
    if (out.length <= 800) return out;
    return '${out.substring(0, 800)}…';
  }
}


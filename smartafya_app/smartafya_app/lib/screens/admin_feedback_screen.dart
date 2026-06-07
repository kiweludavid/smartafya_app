import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import 'admin_feedback_detail_screen.dart';
import 'app_palette.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;
  List<FeedbackDto> _items = [];

  List<SessionDto> _sessions = [];
  List<AdminUserDto> _users = [];
  List<DoctorDto> _doctors = [];

  // Filters
  int? _ratingAtMost; // e.g. 2 => low ratings only
  String? _doctorId;
  DateTimeRange? _rangeLocal;
  bool _sortLowFirst = false;

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
      final results = await Future.wait([
        _api.fetchFeedbackForAdmin(),
        _api.fetchSessions(),
        _api.fetchAllUsersForAdmin(),
        _api.fetchDoctors(availableOnly: false),
      ]);
      final feedback = results[0] as List<FeedbackDto>;
      final sessions = results[1] as List<SessionDto>;
      final users = results[2] as List<AdminUserDto>;
      final doctors = results[3] as List<DoctorDto>;

      if (!mounted) return;
      setState(() {
        _items = feedback;
        _sessions = sessions;
        _users = users;
        _doctors = doctors;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = messageFromDioException(e) ?? 'Failed to load feedback.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load feedback.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSorted();
    final insights = _insights(filtered);

    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        elevation: 0,
        foregroundColor: SmartAfyaPalette.deepText,
        title: const Text('Client Feedback', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _loading ? null : () => _openFiltersSheet(),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
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
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _InsightsCard(
                          avg: insights.avgRating,
                          total: insights.totalCount,
                          lowPercent: insights.lowRatingsPercent,
                        ),
                        const SizedBox(height: 12),
                        _FilterChips(
                          ratingAtMost: _ratingAtMost,
                          doctorName: _doctorId == null ? null : _doctorNameById(_doctorId!),
                          range: _rangeLocal,
                          sortLowFirst: _sortLowFirst,
                          onClearAll: () => setState(() {
                            _ratingAtMost = null;
                            _doctorId = null;
                            _rangeLocal = null;
                            _sortLowFirst = false;
                          }),
                          onToggleSort: () => setState(() => _sortLowFirst = !_sortLowFirst),
                        ),
                        const SizedBox(height: 10),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text(
                                'No feedback found.',
                                style: TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                        else
                          for (final f in filtered) ...[
                            _FeedbackCard(
                              clientName: _clientNameForFeedback(f),
                              doctorName: _doctorNameForFeedback(f),
                              sessionDateLabel: _sessionWhenForFeedback(f),
                              rating: f.rating,
                              preview: f.primaryComment,
                              reviewed: f.reviewed,
                              flagged: f.flagged,
                              onOpen: () async {
                                final updated = await Navigator.push<FeedbackDto>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminFeedbackDetailScreen(
                                      feedback: f,
                                      clientName: _clientNameForFeedback(f),
                                      doctorName: _doctorNameForFeedback(f),
                                      sessionWhenLabel: _sessionWhenForFeedback(f),
                                    ),
                                  ),
                                );
                                if (!mounted || updated == null) return;
                                setState(() {
                                  _items = _items.map((x) => x.id == updated.id ? updated : x).toList();
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
        ),
      ),
    );
  }

  Map<String, SessionDto> get _sessionById => {for (final s in _sessions) s.id: s};

  List<FeedbackDto> _filteredSorted() {
    final bySessionId = _sessionById;

    final list = _items.where((f) {
      if (_ratingAtMost != null) {
        final r = f.rating;
        if (r == null) return false;
        if (r > _ratingAtMost!) return false;
      }
      if (_doctorId != null && _doctorId!.trim().isNotEmpty) {
        final docId = f.doctorId ?? bySessionId[f.sessionId]?.doctorId;
        if ((docId ?? '').trim() != _doctorId) return false;
      }
      if (_rangeLocal != null) {
        final when = DateTime.tryParse(bySessionId[f.sessionId]?.scheduledAt ?? '')?.toLocal();
        if (when == null) return false;
        final start = DateTime(_rangeLocal!.start.year, _rangeLocal!.start.month, _rangeLocal!.start.day);
        final end = DateTime(_rangeLocal!.end.year, _rangeLocal!.end.month, _rangeLocal!.end.day).add(const Duration(days: 1));
        if (when.isBefore(start) || !when.isBefore(end)) return false;
      }
      return true;
    }).toList();

    int cmp(FeedbackDto a, FeedbackDto b) {
      if (_sortLowFirst) {
        final ra = a.rating ?? 999;
        final rb = b.rating ?? 999;
        final byRating = ra.compareTo(rb);
        if (byRating != 0) return byRating;
      }
      final da = DateTime.tryParse(bySessionId[a.sessionId]?.scheduledAt ?? '')?.toLocal() ?? a.createdAtUtc?.toLocal();
      final db = DateTime.tryParse(bySessionId[b.sessionId]?.scheduledAt ?? '')?.toLocal() ?? b.createdAtUtc?.toLocal();
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    }

    list.sort(cmp);
    return list;
  }

  _Insights _insights(List<FeedbackDto> items) {
    final ratings = items.map((e) => e.rating).whereType<int>().where((r) => r >= 1 && r <= 5).toList();
    if (ratings.isEmpty) return _Insights(avgRating: 0, totalCount: items.length, lowRatingsPercent: 0);
    final avg = (ratings.reduce((a, b) => a + b) / ratings.length).toDouble();
    final low = ratings.where((r) => r <= 2).length;
    final lowPct = ratings.isEmpty ? 0 : ((low / ratings.length) * 100).toDouble();
    return _Insights(avgRating: avg, totalCount: items.length, lowRatingsPercent: lowPct.toDouble());
  }

  String _clientNameForFeedback(FeedbackDto f) {
    final session = _sessionById[f.sessionId];
    final clientId = (f.clientId ?? session?.clientId ?? '').trim();
    final u = _users.where((x) => x.id == clientId).toList();
    if (u.isNotEmpty) {
      final name = u.first.fullName.trim().isEmpty ? u.first.email : u.first.fullName.trim();
      return name;
    }
    if (clientId.isEmpty) return 'Client';
    return 'Client …${_tail(clientId)}';
  }

  String _doctorNameForFeedback(FeedbackDto f) {
    final session = _sessionById[f.sessionId];
    final id = (f.doctorId ?? session?.doctorId ?? '').trim();
    if (id.isEmpty) return '—';
    return _doctorNameById(id);
  }

  String _doctorNameById(String id) {
    final list = _doctors.where((d) => d.id == id).toList();
    if (list.isEmpty) return 'Doctor …${_tail(id)}';
    final d = list.first;
    return d.fullName.trim().isEmpty ? d.email : d.fullName.trim();
  }

  String _sessionWhenForFeedback(FeedbackDto f) {
    final s = _sessionById[f.sessionId];
    final dt = DateTime.tryParse(s?.scheduledAt ?? '')?.toLocal();
    if (dt == null) return 'Time TBD';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Filters', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _ratingAtMost,
                  decoration: const InputDecoration(labelText: 'Rating (low only)', filled: true),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All ratings')),
                    DropdownMenuItem(value: 2, child: Text('≤ 2 stars')),
                    DropdownMenuItem(value: 1, child: Text('≤ 1 star')),
                  ],
                  onChanged: (v) => setState(() => _ratingAtMost = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _doctorId,
                  decoration: const InputDecoration(labelText: 'Doctor', filled: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All doctors')),
                    ..._doctors.map((d) => DropdownMenuItem(value: d.id, child: Text(d.fullName.isEmpty ? d.email : d.fullName))),
                  ],
                  onChanged: (v) => setState(() => _doctorId = v),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final pickedRange = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: _rangeLocal,
                    );
                    if (!mounted) return;
                    if (pickedRange != null) setState(() => _rangeLocal = pickedRange);
                  },
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(_rangeLocal == null ? 'Pick date range' : 'Date range set'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
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
}

class _Insights {
  const _Insights({required this.avgRating, required this.totalCount, required this.lowRatingsPercent});
  final double avgRating;
  final int totalCount;
  final double lowRatingsPercent;
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.avg, required this.total, required this.lowPercent});
  final double avg;
  final int total;
  final double lowPercent;

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
      child: Row(
        children: [
          Expanded(child: _Insight(label: 'Average rating', value: avg == 0 ? '—' : avg.toStringAsFixed(1))),
          Expanded(child: _Insight(label: 'Total feedback', value: total.toString())),
          Expanded(child: _Insight(label: 'Low ratings', value: '${lowPercent.toStringAsFixed(0)}%')),
        ],
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText, fontSize: 16)),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.ratingAtMost,
    required this.doctorName,
    required this.range,
    required this.sortLowFirst,
    required this.onClearAll,
    required this.onToggleSort,
  });

  final int? ratingAtMost;
  final String? doctorName;
  final DateTimeRange? range;
  final bool sortLowFirst;
  final VoidCallback onClearAll;
  final VoidCallback onToggleSort;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (ratingAtMost != null) chips.add(_chip('Low ratings ≤ $ratingAtMost'));
    if (doctorName != null && doctorName!.trim().isNotEmpty) chips.add(_chip('Doctor: $doctorName'));
    if (range != null) chips.add(_chip('Date range active'));
    chips.add(ActionChip(
      label: Text(sortLowFirst ? 'Sorting: low→high' : 'Sorting: newest'),
      onPressed: onToggleSort,
      labelStyle: const TextStyle(fontWeight: FontWeight.w900),
    ));

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [...chips.map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w))]),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onClearAll, child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w900))),
      ],
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: SmartAfyaPalette.mutedText)),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.clientName,
    required this.doctorName,
    required this.sessionDateLabel,
    required this.rating,
    required this.preview,
    required this.reviewed,
    required this.flagged,
    required this.onOpen,
  });

  final String clientName;
  final String doctorName;
  final String sessionDateLabel;
  final int? rating;
  final String preview;
  final bool reviewed;
  final bool flagged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EEF7)),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(clientName, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(reviewed: reviewed, flagged: flagged),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$doctorName · $sessionDateLabel',
                style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stars(rating: rating ?? 0),
                  const SizedBox(width: 10),
                  Text(rating == null ? '—' : '$rating/5', style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                preview.trim().isEmpty ? '—' : preview.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.reviewed, required this.flagged});
  final bool reviewed;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final label = flagged
        ? 'Flagged'
        : reviewed
            ? 'Reviewed'
            : 'Not reviewed';
    final bg = flagged
        ? const Color(0xFFFFF4E5)
        : reviewed
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFF3F6F9);
    final fg = flagged
        ? const Color(0xFFB8860B)
        : reviewed
            ? SmartAfyaPalette.primaryGreen
            : SmartAfyaPalette.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: fg)),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0, 5);
    return Row(
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= r ? Icons.star_rounded : Icons.star_border_rounded,
            size: 18,
            color: i <= r ? const Color(0xFFFFC107) : SmartAfyaPalette.mutedText,
          ),
      ],
    );
  }
}


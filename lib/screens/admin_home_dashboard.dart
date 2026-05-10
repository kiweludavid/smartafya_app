import 'package:flutter/material.dart';

import 'admin_requests_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_assign_specialist_screen.dart';
import 'admin_schedule_session_screen.dart';
import 'admin_sessions_screen.dart';
import 'app_palette.dart';
import '../services/api_service.dart';

/// Admin home: operations entry points for core admin workflows.
class AdminHomeDashboard extends StatefulWidget {
  const AdminHomeDashboard({
    super.key,
    required this.onRefresh,
  });

  final Future<void> Function() onRefresh;

  @override
  State<AdminHomeDashboard> createState() => _AdminHomeDashboardState();
}

class _AdminHomeDashboardState extends State<AdminHomeDashboard> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;

  // Top stats
  int _newRequests = 0;
  int _pendingAssignments = 0;
  int _scheduledToday = 0;
  int _reportsSubmitted = 0;

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
        _api.fetchAllBookings(),
        _api.fetchSessions(),
        _api.fetchDoctors(availableOnly: false),
      ]);
      final bookings = results[0] as List<BookingDto>;
      final sessions = results[1] as List<SessionDto>;
      // ignore: unused_local_variable
      final doctors = results[2] as List<DoctorDto>;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      int newRequests = 0;
      for (final b in bookings) {
        final st = b.status.toLowerCase();
        if (st == 'pending') newRequests++;
      }

      int pendingAssignments = 0;
      int scheduledToday = 0;
      int reports = 0;
      for (final s in sessions) {
        final st = s.status.toLowerCase();
        final unassigned = (s.doctorId ?? '').trim().isEmpty;
        if (unassigned && (st == 'requested' || st == 'pending' || st == 'scheduled')) {
          pendingAssignments++;
        }
        final dt = DateTime.tryParse(s.scheduledAt ?? '')?.toLocal();
        if (dt != null && !dt.isBefore(startOfDay) && dt.isBefore(endOfDay) && (st == 'scheduled' || st == 'pending')) {
          scheduledToday++;
        }
        final notes = (s.notes ?? '');
        if (notes.contains('CONSULTATION_REPORT:')) reports++;
      }

      if (!mounted) return;
      setState(() {
        _newRequests = newRequests;
        _pendingAssignments = pendingAssignments;
        _scheduledToday = scheduledToday;
        _reportsSubmitted = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load admin overview. Pull down to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: SmartAfyaPalette.primaryBlue,
      onRefresh: () async {
        await _load();
        await widget.onRefresh();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            'Smart Afya · Admin',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: SmartAfyaPalette.deepText,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 16),

          if (_loading) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 14),
          ] else if (_error != null) ...[
            _InfoBanner(
              icon: Icons.wifi_off_rounded,
              title: 'Offline overview',
              message: _error!,
              actionText: 'Retry',
              onAction: _load,
            ),
            const SizedBox(height: 14),
          ],

          _SectionTitle(
            title: 'Overview',
          ),
          const SizedBox(height: 12),
          _OverviewCards(
            loading: _loading,
            newRequests: _newRequests,
            pendingAssignments: _pendingAssignments,
            sessionsToday: _scheduledToday,
            reportsSubmitted: _reportsSubmitted,
            onOpenNewRequests: () => _push(context, const AdminRequestsScreen(initialFilterIndex: 1)),
            onOpenPendingAssignments: () => _push(context, const AdminAssignSpecialistScreen()),
            onOpenSessionsToday: () => _push(context, const AdminSessionsScreen()),
            onOpenReports: () => _push(context, const AdminReportsScreen()),
          ),
          const SizedBox(height: 18),

          _SectionTitle(
            title: 'Quick Actions',
          ),
          const SizedBox(height: 12),
          _QuickActionsRow(
            items: [
              _QuickActionData(
                icon: Icons.person_add_alt_1_outlined,
                iconBg: const Color(0xFFC9EFE4),
                iconColor: SmartAfyaPalette.primaryGreen,
                title: 'Assign Specialist',
                subtitle: 'Match client to a specialist',
                onTap: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute<bool>(builder: (_) => const AdminAssignSpecialistScreen()),
                  );
                  if (ok == true && context.mounted) {
                    await _load();
                    await widget.onRefresh();
                  }
                },
              ),
              _QuickActionData(
                icon: Icons.calendar_month_outlined,
                iconBg: const Color(0xFFDAE9F5),
                iconColor: SmartAfyaPalette.primaryBlue,
                title: 'Schedule Session',
                subtitle: 'Set date and time',
                onTap: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute<bool>(builder: (_) => const AdminScheduleSessionScreen()),
                  );
                  if (created == true && context.mounted) {
                    await _load();
                    await widget.onRefresh();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Future<void> _push(BuildContext context, Widget screen) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: SmartAfyaPalette.deepText,
                      letterSpacing: -0.2,
                    ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionText,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionText;
  final VoidCallback onAction;

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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SmartAfyaPalette.softBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SmartAfyaPalette.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: SmartAfyaPalette.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.icon,
    required this.color,
    required this.title,
    required this.valueText,
    required this.onTap,
    this.emphasize = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String valueText;
  final VoidCallback onTap;
  final bool emphasize;
}

class _StatCard extends StatefulWidget {
  const _StatCard({required this.data});
  final _StatCardData data;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: d.emphasize ? SmartAfyaPalette.primaryBlue : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: d.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: d.emphasize ? const Color(0x00000000) : const Color(0xFFE4EEF7)),
              boxShadow: d.emphasize
                  ? const [BoxShadow(color: Color(0x240B5FFF), blurRadius: 18, offset: Offset(0, 10))]
                  : const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: d.emphasize ? Colors.white.withValues(alpha: 0.16) : d.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(d.icon, color: d.emphasize ? Colors.white : d.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        d.valueText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          color: d.emphasize ? Colors.white : SmartAfyaPalette.deepText,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        d.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: d.emphasize ? Colors.white.withValues(alpha: 0.9) : SmartAfyaPalette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: d.emphasize ? Colors.white.withValues(alpha: 0.9) : SmartAfyaPalette.mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards({
    required this.loading,
    required this.newRequests,
    required this.pendingAssignments,
    required this.sessionsToday,
    required this.reportsSubmitted,
    required this.onOpenNewRequests,
    required this.onOpenPendingAssignments,
    required this.onOpenSessionsToday,
    required this.onOpenReports,
  });

  final bool loading;
  final int newRequests;
  final int pendingAssignments;
  final int sessionsToday;
  final int reportsSubmitted;
  final VoidCallback onOpenNewRequests;
  final VoidCallback onOpenPendingAssignments;
  final VoidCallback onOpenSessionsToday;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    final newRequestsCard = _StatCard(
      data: _StatCardData(
        icon: Icons.inbox_outlined,
        color: SmartAfyaPalette.primaryBlue,
        title: 'New Requests',
        valueText: '$newRequests New Requests',
        emphasize: true,
        onTap: onOpenNewRequests,
      ),
    );

    final others = [
      _StatCard(
        data: _StatCardData(
          icon: Icons.person_search_outlined,
          color: SmartAfyaPalette.primaryGreen,
          title: 'Pending Assignments',
          valueText: '$pendingAssignments Pending',
          onTap: onOpenPendingAssignments,
        ),
      ),
      _StatCard(
        data: _StatCardData(
          icon: Icons.today_outlined,
          color: SmartAfyaPalette.primaryBlue,
          title: 'Sessions Today',
          valueText: '$sessionsToday Today',
          onTap: onOpenSessionsToday,
        ),
      ),
      _StatCard(
        data: _StatCardData(
          icon: Icons.article_outlined,
          color: SmartAfyaPalette.primaryGreen,
          title: 'Reports Submitted',
          valueText: '$reportsSubmitted Submitted',
          onTap: onOpenReports,
        ),
      ),
    ];

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: newRequestsCard),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: others[0]),
                    const SizedBox(width: 12),
                    Expanded(child: others[1]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: others[2]),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        newRequestsCard,
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: width >= 600 ? 3 : 1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: width >= 600 ? 2.15 : 3.2,
          ),
          itemCount: others.length,
          itemBuilder: (_, i) => others[i],
        ),
      ],
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.items});
  final List<_QuickActionData> items;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900 && items.length >= 2) {
      return Row(
        children: [
          Expanded(child: _QuickActionCard(data: items[0])),
          const SizedBox(width: 14),
          Expanded(child: _QuickActionCard(data: items[1])),
        ],
      );
    }
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _QuickActionCard(data: items[i]),
          if (i != items.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({required this.data});
  final _QuickActionData data;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: d.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
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
                        color: d.iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(d.icon, color: d.iconColor, size: 24),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: SmartAfyaPalette.mutedText),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  d.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.2, color: SmartAfyaPalette.deepText),
                ),
                const SizedBox(height: 5),
                Text(
                  d.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.2, color: SmartAfyaPalette.mutedText, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

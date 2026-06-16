import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smart_afya/l10n/app_localizations.dart';

import '../l10n/format_helpers.dart';
import '../l10n/l10n_extensions.dart';
import '../services/api_service.dart';
import '../utils/dio_error_message.dart';
import '../utils/payment_status.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../state/client_home_controller.dart';
import '../utils/person_name.dart';
import 'appointment_detail_screen.dart';
import 'appointments_screen.dart';
import 'doctor_appointments_screen.dart';
import 'create_booking_screen.dart';
import 'mental_health_form_screen.dart';
// care_actions_screen.dart intentionally not imported in home dashboard
import 'chat_list_screen.dart';
import 'client_medical_records_screen.dart';
// client_session_feedback_screen.dart intentionally not imported in home dashboard
import 'doctor_home_dashboard.dart';
import 'doctor_schedule_screen.dart';
import 'doctor_profile_screen.dart';
import 'app_palette.dart';
import 'client_profile_screen.dart';

/// Shared, cheap decorations (same file — avoids heavy blur radii on weak GPUs).
const _kHairlineBorder = Color(0xFFE4EEF7);
const List<BoxShadow> _kShadowSoft = [
  BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
];
const List<BoxShadow> _kShadowNav = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -4)),
];

enum _HomeLoadError { profile, timeout, general }

/// Pixel-perfect home screen matching the provided design image.
///
/// Note: App-wide Inter font is applied via ThemeData in `main.dart`.
class SmartAfyaHomeScreenUi extends StatefulWidget {
  const SmartAfyaHomeScreenUi({super.key});

  @override
  State<SmartAfyaHomeScreenUi> createState() => _SmartAfyaHomeScreenUiState();
}

class _SmartAfyaHomeScreenUiState extends State<SmartAfyaHomeScreenUi>
    with WidgetsBindingObserver {
  // Design tokens
  static const _edge = 16.0;

  // Simple vertical gradient (cheaper than diagonal + extra decorative layers).
  static const _bgTop = Color(0xFFEAF4FB);
  static const _bgBottom = Color(0xFFF7F9FC);

  static const _sectionGap = 22.0;

  int _navIndex = 0;

  final _api = ApiService();

  bool _isLoading = true;
  bool _hasError = false;
  _HomeLoadError? _loadError;
  CurrentUserDto? _user;
  SessionDto? _upcomingSession;
  BookingDto? _upcomingBooking;

  bool _hasSubmittedForm = false;
  bool _hasBookedSession = false;
  bool _hasMadePayment = false;

  bool? _doctorIsAvailable;
  bool _availabilityBusy = false;
  List<SessionDto> _doctorSessions = [];
  Map<String, BookingDto> _doctorBookingById = {};
  DoctorDashboardSummaryDto? _doctorSummary;
  int _doctorMessageThreads = 0;

  // Money/duration/payment guidance is part of the booking flow (not the home dashboard).

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_hasError) {
      final l10n = context.l10n;
      final errorMessage = switch (_loadError) {
        _HomeLoadError.profile => l10n.couldNotLoadProfileRetry,
        _HomeLoadError.timeout => l10n.homeLoadTimedOut,
        _HomeLoadError.general => l10n.couldNotLoadHomeRetry,
        null => l10n.couldNotLoadHomeData,
      };
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final user = _user;
    final isDoctor = user != null && user.isDoctor;
    final greetingFirstName = user != null && user.fullName.trim().isNotEmpty
        ? firstNameFromFullName(user.fullName)
        : null;
    final specialist = (user?.specialistType ?? '').trim();
    final l10n = context.l10n;
    final badgeText = isDoctor
        ? (specialist.isNotEmpty ? specialist : l10n.roleDoctor)
        : l10n.roleClient;

    final upcoming = _upcomingSession;
    final booking = _upcomingBooking;
    final hasUpcoming = upcoming != null;

    final whenText = hasUpcoming
        ? formatScheduledWhenLong(context, _parseLocal(upcoming.scheduledAt))
        : null;
    final typeLabel = localizedSessionType(l10n, booking?.sessionType);
    final doctorLabel = _doctorLabel(upcoming?.doctorId);
    final detail2 = hasUpcoming ? _buildConsultationLine(typeLabel: typeLabel, doctorLabel: doctorLabel) : null;

    void openDoctorSessions() {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DoctorSessionsScreen(
            sessions: _doctorSessions,
            bookingsById: _doctorBookingById,
            initialFilterIndex: 2, // Upcoming
            onSessionUpdated: (_) => _load(),
          ),
        ),
      );
    }

    void openDoctorSchedule() {
      final u = user;
      if (u == null) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DoctorScheduleScreen(
            sessions: _doctorSessions,
            bookingsById: _doctorBookingById,
            isAvailable: _doctorIsAvailable ?? u.isAvailable,
            availabilityBusy: _availabilityBusy,
            onToggleAvailability: _toggleAvailability,
            onRefresh: _load,
          ),
        ),
      );
    }

    void openMessages() {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const ChatListScreen()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: isDoctor
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(_edge, 22, _edge, 0),
                                child: DoctorHomeDashboard(
                                  user: user,
                                  sessions: _doctorSessions,
                                  bookingsById: _doctorBookingById,
                                  isAvailable: _doctorIsAvailable ?? user.isAvailable,
                                  availabilityBusy: _availabilityBusy,
                                  onToggleAvailability: _toggleAvailability,
                                  onRefresh: _load,
                                  onOpenSchedule: openDoctorSchedule,
                                  onOpenSessionsAndReports: openDoctorSessions,
                                  pendingTransferRequestsCount: _doctorSummary?.pendingTransferRequestsCount ?? 0,
                                  pendingUnavailabilityImpactsCount: _doctorSummary?.pendingUnavailabilityImpactsCount ?? 0,
                                  messageThreadsCount: _doctorMessageThreads,
                                  onOpenMessages: openMessages,
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _refreshAll,
                                color: SmartAfyaPalette.primaryBlue,
                                child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(_edge, 22, _edge, 110),
                                child: (user != null && user.isClient)
                                    ? _ClientHomeDynamic(
                                        greetingFirstName: greetingFirstName,
                                        badgeText: badgeText,
                                        onJoin: (link) => _handleJoin(context, link),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _Header(
                                            greetingFirstName: greetingFirstName,
                                            badgeText: badgeText,
                                            badgeIsDoctor: isDoctor,
                                          ),
                                          const SizedBox(height: _sectionGap),
                                          HeroCard(
                                            hasUpcomingSession: hasUpcoming,
                                            title: hasUpcoming ? l10n.upcomingSession : l10n.startYourCare,
                                            subtitle: hasUpcoming
                                                ? (whenText?.isEmpty == true ? l10n.emDash : (whenText ?? l10n.emDash))
                                                : l10n.bookFirstConsultation,
                                            detailLine: hasUpcoming ? (detail2 ?? l10n.consultation) : null,
                                            primaryActionText: hasUpcoming ? l10n.joinSession : l10n.bookConsultation,
                                            onPrimaryAction: hasUpcoming
                                                ? () => _handleJoin(context, upcoming.meetingLink)
                                                : () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute<void>(
                                                        builder: (_) => const CreateBookingScreen(
                                                          initialSessionType: 'video',
                                                          initialDurationMinutes: 60,
                                                        ),
                                                      ),
                                                    ),
                                            secondaryActionText: hasUpcoming ? l10n.reschedule : null,
                                            onSecondaryAction: hasUpcoming
                                                ? () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
                                                    )
                                                : null,
                                            onCardTap: hasUpcoming
                                                ? () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
                                                    )
                                                : null,
                                          ),
                                          const SizedBox(height: _sectionGap),
                                          if (!_isOnboardingComplete)
                                            ProgressCard(
                                              completed: _onboardingCompletedCount,
                                              total: 3,
                                              steps: ProgressSteps(
                                                hasSubmittedForm: _hasSubmittedForm,
                                                hasBookedSession: _hasBookedSession,
                                                hasMadePayment: _hasMadePayment,
                                              ),
                                              onContinue: () {
                                                if (!_hasSubmittedForm) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(builder: (_) => const MentalHealthFormScreen()),
                                                  );
                                                  return;
                                                }
                                                if (!_hasBookedSession) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                      builder: (_) => const CreateBookingScreen(
                                                        initialSessionType: 'video',
                                                        initialDurationMinutes: 60,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
                                                );
                                              },
                                            ),
                                          if (!_isOnboardingComplete) const SizedBox(height: _sectionGap),
                                          QuickActionsRow(
                                            showJoin: hasUpcoming,
                                            onBookConsultation: () => Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) => const CreateBookingScreen(
                                                  initialSessionType: 'video',
                                                  initialDurationMinutes: 60,
                                                ),
                                              ),
                                            ),
                                            onAppointments: () => Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
                                            ),
                                            onJoinSession: () => _handleJoin(context, upcoming?.meetingLink),
                                          ),
                                        ],
                                      ),
                              ),
                              ),
                  ),
                  _BottomNavBar(
                    currentIndex: _navIndex,
                    onTap: (i) {
                      setState(() => _navIndex = i);
                      if (i == 0) return;
                      void resetHomeNav() {
                        if (mounted) setState(() => _navIndex = 0);
                      }

                      if (i == 1) {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(builder: (_) => const ChatListScreen()),
                        ).then((_) => resetHomeNav());
                        return;
                      }
                      if (i == 2) {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => isDoctor
                                ? const DoctorAppointmentsScreen()
                                : const AppointmentsScreen(),
                          ),
                        ).then((_) => resetHomeNav());
                        return;
                      }
                      if (i == 3) {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                isDoctor ? DoctorProfileScreen(onRefreshParent: _load) : const ProfileScreen(),
                          ),
                        ).then((_) => resetHomeNav());
                        return;
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (Navigation handled by bottom bar callback.)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClientHomeController>().load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-fetch home data when the app returns to the foreground. This is the
  /// "free" way to surface admin-side changes (a session being scheduled,
  /// payment confirmed, doctor assigned, etc.) without forcing the user to
  /// pull-to-refresh after every background trip.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  /// Single entry point used by pull-to-refresh and the lifecycle observer.
  /// Refreshes both the local user/session pipeline and the dynamic
  /// ClientHomeController in parallel, swallowing errors so the gesture
  /// always completes cleanly.
  Future<void> _refreshAll() async {
    if (!mounted) return;
    final controllerLoad = context.read<ClientHomeController>().load();
    final userLoad = _load();
    try {
      await Future.wait<void>([controllerLoad, userLoad]);
    } catch (_) {
      // Errors surface through the existing _hasError / controller state.
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _loadError = null;
    });

    late final CurrentUserDto loadedUser;
    try {
      loadedUser = await fetchUser().timeout(const Duration(seconds: 6));
    } on DioException catch (e) {
      debugPrint('Home /users/me failed: $e');
      if (e.response?.statusCode == 401) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loadError = _HomeLoadError.profile;
        _isLoading = false;
      });
      return;
    } on TimeoutException catch (e) {
      debugPrint('Home /users/me timed out: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loadError = _HomeLoadError.timeout;
        _isLoading = false;
      });
      return;
    } catch (e) {
      debugPrint('Home /users/me failed: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loadError = _HomeLoadError.general;
        _isLoading = false;
      });
      return;
    }

    // Only client and doctor roles are supported in mobile.
    if (!loadedUser.isClient && !loadedUser.isDoctor) {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }

    try {
      final sessions = await fetchSessions().timeout(const Duration(seconds: 6));
      List<BookingDto> bookings = [];
      if (!loadedUser.isDoctor) {
        try {
          bookings = await fetchBookings().timeout(const Duration(seconds: 6));
        } on DioException catch (e) {
          debugPrint('Bookings load skipped/failed: $e');
          bookings = [];
        }
      }
      final upcoming = loadedUser.isDoctor ? null : getUpcomingSession(user: loadedUser, sessions: sessions);
      final booking = (upcoming == null)
          ? null
          : bookings.cast<BookingDto?>().firstWhere(
                (b) => b?.id == upcoming.bookingId,
                orElse: () => null,
              );
      final payment = upcoming == null
          ? null
          : await _api.fetchPaymentForSession(upcoming.id).timeout(const Duration(seconds: 6));

      var doctorSessions = <SessionDto>[];
      var doctorBookingById = <String, BookingDto>{};
      DoctorDashboardSummaryDto? doctorSummary;
      int doctorMessageThreads = 0;
      if (loadedUser.isDoctor) {
        doctorSessions = sessions.where((s) => s.doctorId == loadedUser.id).toList();
        final ids = doctorSessions.map((s) => s.bookingId).toSet();
        await Future.wait(
          ids.map((id) async {
            try {
              final b = await _api.fetchBookingById(id).timeout(const Duration(seconds: 5));
              doctorBookingById[id] = b;
            } catch (_) {}
          }),
        );
        try {
          doctorSummary = await _api.fetchDoctorDashboardSummary().timeout(const Duration(seconds: 5));
        } catch (_) {
          doctorSummary = null;
        }
        try {
          final conversations = await _api.fetchChatConversations().timeout(const Duration(seconds: 5));
          doctorMessageThreads = conversations.length;
        } catch (_) {
          doctorMessageThreads = 0;
        }
      }

      if (!mounted) return;
      final hasBooking = bookings.isNotEmpty;
      final hasForm = bookings.any((b) => (b.mentalHealthDescription ?? '').trim().isNotEmpty);
      final pStatus = (payment?.status ?? '').toLowerCase();
      final hasPaid =
          pStatus == 'paid' || pStatus == 'completed' || pStatus == 'success' || pStatus == 'successful';
      setState(() {
        _user = loadedUser;
        _upcomingSession = upcoming;
        _upcomingBooking = booking;
        _hasBookedSession = hasBooking;
        _hasSubmittedForm = hasForm;
        _hasMadePayment = hasPaid;
        _doctorIsAvailable = loadedUser.isDoctor ? loadedUser.isAvailable : null;
        _doctorSessions = doctorSessions;
        _doctorBookingById = doctorBookingById;
        _doctorSummary = doctorSummary;
        _doctorMessageThreads = doctorMessageThreads;
        _isLoading = false;
      });
    } on DioException catch (e) {
      debugPrint('Home sessions/bookings load failed: $e');
      debugPrint(
        'DioException: status=${e.response?.statusCode} '
        'type=${e.type} '
        'path=${e.requestOptions.path}',
      );
      if (e.response?.statusCode == 401) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _user = loadedUser;
        _isLoading = false;
        _upcomingSession = null;
        _upcomingBooking = null;
        _hasBookedSession = false;
        _hasSubmittedForm = false;
        _hasMadePayment = false;
        _doctorIsAvailable = loadedUser.isDoctor ? loadedUser.isAvailable : null;
        _doctorSessions = [];
        _doctorBookingById = {};
        _doctorSummary = null;
        _doctorMessageThreads = 0;
      });
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loadedUser.isDoctor
                  ? l10n.couldNotLoadSessionsPullToRetry
                  : l10n.couldNotLoadAllDataPullToRetry,
            ),
          ),
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('Home secondary load timed out: $e');
      if (!mounted) return;
      setState(() {
        _user = loadedUser;
        _isLoading = false;
        _upcomingSession = null;
        _upcomingBooking = null;
        _hasBookedSession = false;
        _hasSubmittedForm = false;
        _hasMadePayment = false;
        _doctorIsAvailable = loadedUser.isDoctor ? loadedUser.isAvailable : null;
        _doctorSessions = [];
        _doctorBookingById = {};
        _doctorSummary = null;
        _doctorMessageThreads = 0;
      });
    } catch (e) {
      debugPrint('Home secondary load failed: $e');
      if (!mounted) return;
      setState(() {
        _user = loadedUser;
        _isLoading = false;
        _upcomingSession = null;
        _upcomingBooking = null;
        _hasBookedSession = false;
        _hasSubmittedForm = false;
        _hasMadePayment = false;
        _doctorIsAvailable = loadedUser.isDoctor ? loadedUser.isAvailable : null;
        _doctorSessions = [];
        _doctorBookingById = {};
        _doctorSummary = null;
        _doctorMessageThreads = 0;
      });
    }
  }

  Future<CurrentUserDto> fetchUser() => _api.fetchCurrentUser();

  Future<List<SessionDto>> fetchSessions() => _api.fetchSessions();

  Future<List<BookingDto>> fetchBookings() => _api.fetchMyBookings();

  Future<void> _toggleAvailability() async {
    final user = _user;
    if (user == null || !user.isDoctor) return;
    final next = !(_doctorIsAvailable ?? user.isAvailable);
    setState(() {
      _availabilityBusy = true;
      _doctorIsAvailable = next;
    });
    try {
      await _api.updateDoctorAvailability(isAvailable: next).timeout(const Duration(seconds: 6));
    } on DioException catch (e) {
      debugPrint('Update availability failed: $e');
      if (!mounted) return;
      setState(() {
        _doctorIsAvailable = !next;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update availability. Please try again.')),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _doctorIsAvailable = !next;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability update timed out.')),
      );
    } finally {
      if (mounted) setState(() => _availabilityBusy = false);
    }
  }

  int get _onboardingCompletedCount {
    final steps = <bool>[_hasSubmittedForm, _hasBookedSession, _hasMadePayment];
    return steps.where((x) => x).length;
  }

  bool get _isOnboardingComplete => _onboardingCompletedCount >= 3;

  SessionDto? getUpcomingSession({
    required CurrentUserDto user,
    required List<SessionDto> sessions,
  }) {
    final now = DateTime.now();
    final upcoming = sessions
        .where((s) => s.clientId == user.id)
        .map((s) {
          final dt = _parseLocal(s.scheduledAt);
          return (s: s, dt: dt);
        })
        .where((x) => x.dt != null && x.dt!.isAfter(now))
        .toList()
      ..sort((a, b) => a.dt!.compareTo(b.dt!));

    return upcoming.isEmpty ? null : upcoming.first.s;
  }

  static DateTime? _parseLocal(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    return dt?.toLocal();
  }

  static String _doctorLabel(String? doctorId) {
    if (doctorId == null || doctorId.isEmpty) return '';
    // We only use /users/me + /sessions/ (+ bookings for session type).
    // Doctor name is not available on SessionDto currently.
    return '';
  }

  static String _buildConsultationLine({
    required String typeLabel,
    required String doctorLabel,
  }) {
    if (doctorLabel.isEmpty) return typeLabel;
    return '$typeLabel - $doctorLabel';
  }

  Future<void> _handleJoin(BuildContext context, String? meetingLink) async {
    final link = (meetingLink ?? '').trim();
    if (link.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sessionLinkNotAvailable)),
      );
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sessionLinkNotAvailable)),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sessionLinkNotAvailable)),
      );
    }
  }

  // Payments + feedback flows intentionally removed from the home screen
  // to keep the dashboard focused and state-driven.
}

class _ClientHomeDynamic extends StatefulWidget {
  const _ClientHomeDynamic({
    required this.greetingFirstName,
    required this.badgeText,
    required this.onJoin,
  });

  final String? greetingFirstName;
  final String badgeText;
  final void Function(String? meetingLink) onJoin;

  static const _edge = 16.0;
  static const _sectionGap = 18.0;

  @override
  State<_ClientHomeDynamic> createState() => _ClientHomeDynamicState();
}

class _ClientHomeDynamicState extends State<_ClientHomeDynamic> {
  // Match auth + doctor dashboard primary color.
  static const _indigo = SmartAfyaPalette.primaryBlue;
  static const _hairline = Color(0xFFE4EEF7);
  static const List<BoxShadow> _premiumShadow = [
    BoxShadow(color: Color(0x12000000), blurRadius: 22, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  final _api = ApiService();
  String? _activeConversationId;
  bool _loadingActiveChat = false;
  final Set<String> _dismissedMissedBannerSessionIds = <String>{};

  Future<void> _ensureActiveChatLoaded(String sessionId) async {
    if (_loadingActiveChat) return;
    if ((_activeConversationId ?? '').isNotEmpty) return;
    _loadingActiveChat = true;
    try {
      final items = await _api.fetchChatConversations().timeout(const Duration(seconds: 5));
      final hit = items
          .where((c) => c.kind.toLowerCase().trim() == 'session' && (c.sessionId ?? '') == sessionId)
          .toList();
      if (!mounted) return;
      setState(() => _activeConversationId = hit.isEmpty ? null : hit.first.id);
    } catch (_) {
      // Silent: if chat isn't available, we just don't show the card.
    } finally {
      _loadingActiveChat = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final greeting = timeGreeting(l10n, now);
    final firstName = (widget.greetingFirstName ?? '').trim().isEmpty
        ? l10n.greetingThere
        : widget.greetingFirstName!.trim();

    Widget cardShell({required Widget child, VoidCallback? onTap}) {
      final decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hairline),
        boxShadow: _premiumShadow,
      );
      const padding = EdgeInsets.all(18);
      if (onTap == null) {
        return Container(padding: padding, decoration: decoration, child: child);
      }
      return Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }

    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: SmartAfyaPalette.mutedText,
              letterSpacing: 0.2,
            ),
          ),
        );

    return Consumer<ClientHomeController>(
      builder: (context, c, _) {
        final s = c.state;
        if (s.isLoading) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue)),
          );
        }

        if (s.errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.couldNotLoadHomeDataPullToRetry, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: c.load,
                    style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }

        final upcoming = s.upcomingSession;
        final upcomingSessions = s.upcomingSessions;
        final paymentsBySessionId = s.paymentsBySessionId;
        final hasUpcoming = upcoming != null;

        final bookingsById = <String, BookingDto>{
          for (final b in s.bookings) b.id: b,
        };
        final doctorsById = s.doctorsById;

        Future<void> openAppointments() async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
          );
          if (!context.mounted) return;
          c.load();
        }

        Future<void> openSessionDetail(SessionDto session) async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(
              builder: (_) => AppointmentDetailScreen(
                session: session,
                booking: bookingsById[session.bookingId],
                doctor: (session.doctorId ?? '').isNotEmpty ? doctorsById[session.doctorId!] : null,
                payment: paymentsBySessionId[session.id],
              ),
            ),
          );
          if (!context.mounted) return;
          if (result == true) c.load();
        }

        if (upcoming != null && (upcoming.doctorId ?? '').trim().isNotEmpty) {
          _ensureActiveChatLoaded(upcoming.id);
        }

        final missed = s.latestMissedSession;
        final credit = s.sessionCreditBalance;
        final showCreditBanner = credit >= 0.01;
        final showMissedBanner =
            missed != null && missed.id.isNotEmpty && !_dismissedMissedBannerSessionIds.contains(missed.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(_ClientHomeDynamic._edge, 8, _ClientHomeDynamic._edge, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.greetingWithName(greeting, firstName),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: SmartAfyaPalette.deepText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.careTodaySummary,
                    style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            if (showCreditBanner) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _ClientHomeDynamic._edge),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: SmartAfyaPalette.softBlue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _hairline),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.redeem_rounded, color: SmartAfyaPalette.primaryBlue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.sessionCreditBanner(credit.toStringAsFixed(2)),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: SmartAfyaPalette.deepText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (showMissedBanner) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _ClientHomeDynamic._edge),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFE0B2)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.event_busy_rounded, color: Color(0xFFE65100), size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.youMissedSession,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: SmartAfyaPalette.deepText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatShortWhen(context, missed.scheduledAt),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: SmartAfyaPalette.mutedText,
                                    ),
                                  ),
                                  if ((missed.doctorId ?? '').isNotEmpty &&
                                      (doctorsById[missed.doctorId!]?.fullName ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.withDoctor(doctorsById[missed.doctorId!]!.fullName.trim()),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: SmartAfyaPalette.mutedText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => _dismissedMissedBannerSessionIds.add(missed.id));
                              },
                              icon: const Icon(Icons.close_rounded, color: SmartAfyaPalette.mutedText),
                              tooltip: l10n.dismiss,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const CreateBookingScreen(
                                        initialSessionType: 'video',
                                        initialDurationMinutes: 60,
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: SmartAfyaPalette.primaryBlue,
                                  side: BorderSide(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.45)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(l10n.reschedule, style: const TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(builder: (_) => const ChatListScreen()),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: SmartAfyaPalette.primaryBlue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(l10n.getHelp, style: const TextStyle(fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: _ClientHomeDynamic._sectionGap),

            // Upcoming-session block.
            //
            // - If the patient has at least one scheduled session, render the
            //   premium upcoming-session card (one card per session).
            // - Otherwise, render a lightweight, calm empty-state card that
            //   nudges the patient toward booking a consultation. The card
            //   itself is tappable and routes into the booking flow.
            if (upcomingSessions.isNotEmpty) ...[
              for (var i = 0; i < upcomingSessions.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _ClientHomeDynamic._edge),
                  child: cardShell(
                    onTap: () => openSessionDetail(upcomingSessions[i]),
                    child: _UpcomingSessionCardBody(
                      session: upcomingSessions[i],
                      booking: bookingsById[upcomingSessions[i].bookingId],
                      doctor: (upcomingSessions[i].doctorId ?? '').isNotEmpty
                          ? doctorsById[upcomingSessions[i].doctorId!]
                          : null,
                      payment: paymentsBySessionId[upcomingSessions[i].id],
                      positionLabel: upcomingSessions.length > 1
                          ? l10n.sessionPosition(i + 1, upcomingSessions.length)
                          : null,
                      onJoin: () => widget.onJoin(upcomingSessions[i].meetingLink),
                      onViewDetails: () => openSessionDetail(upcomingSessions[i]),
                    ),
                  ),
                ),
                SizedBox(height: i == upcomingSessions.length - 1 ? 14 : 12),
              ],
            ] else ...[
              // Empty-state card. Tapping it routes to the appointments
              // screen (consistent with the populated card). The
              // appointments screen has its own "Book a consultation" CTA
              // on its empty Upcoming tab, plus a Completed tab for any
              // past sessions, so this is a richer landing than going
              // straight into the booking form.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _ClientHomeDynamic._edge),
                child: cardShell(
                  onTap: openAppointments,
                  child: const _UpcomingSessionEmptyCardBody(),
                ),
              ),
              const SizedBox(height: 14),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _ClientHomeDynamic._edge),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateBookingScreen(
                        initialSessionType: 'video',
                        initialDurationMinutes: 60,
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    l10n.startNewConsultation,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, letterSpacing: -0.1),
                  ),
                ),
              ),
            ),

            const SizedBox(height: _ClientHomeDynamic._sectionGap),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _ClientHomeDynamic._edge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel(l10n.quickActionsLower),
                  _TwoGrid(
                    left: _ActionTile(
                      icon: Icons.calendar_month_rounded,
                      title: l10n.bookConsultation,
                      subtitle: l10n.bookConsultationSubtitle,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const CreateBookingScreen(
                            initialSessionType: 'video',
                            initialDurationMinutes: 60,
                          ),
                        ),
                      ),
                    ),
                    right: _ActionTile(
                      icon: Icons.event_note_rounded,
                      title: l10n.myAppointments,
                      subtitle: l10n.viewSchedule,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: _ClientHomeDynamic._sectionGap),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _ClientHomeDynamic._edge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel(l10n.more),
                  _TwoGrid(
                    left: _ActionTile(
                      icon: Icons.chat_rounded,
                      title: l10n.navChat,
                      subtitle: l10n.chatSubtitle,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const ChatListScreen()),
                      ),
                    ),
                    right: _ActionTile(
                      icon: Icons.folder_shared_rounded,
                      title: l10n.medicalRecords,
                      subtitle: l10n.yourHistory,
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const ClientMedicalRecordsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (hasUpcoming && (upcoming.doctorId ?? '').trim().isNotEmpty && (_activeConversationId ?? '').isNotEmpty) ...[
              const SizedBox(height: _ClientHomeDynamic._sectionGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _ClientHomeDynamic._edge),
                child: cardShell(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _indigo.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.forum_rounded, color: _indigo),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.continueConversation,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.chatWithSpecialist,
                              style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(builder: (_) => const ChatListScreen()),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _indigo,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(l10n.open, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _TwoGrid extends StatelessWidget {
  const _TwoGrid({required this.left, required this.right});
  final Widget left;
  final Widget right;

  static const _tileHeight = 142.0;

  @override
  Widget build(BuildContext context) {
    // Avoid RenderFlex overflow on smaller screens / larger textScale by
    // using a minimum height while still allowing tiles to grow as needed.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _tileHeight),
              child: left,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _tileHeight),
              child: right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4EEF7)),
            boxShadow: const [
              BoxShadow(color: Color(0x11000000), blurRadius: 22, offset: Offset(0, 12)),
              BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 116),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: SmartAfyaPalette.softBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: SmartAfyaPalette.primaryBlue, size: 24),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: SmartAfyaPalette.mutedText.withValues(alpha: 0.9)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: SmartAfyaPalette.deepText,
                    fontSize: 15.5,
                    letterSpacing: -0.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: SmartAfyaPalette.deepText.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Premium home-dashboard card body for a single scheduled session.
///
/// Layout follows a calm Material 3 healthcare style: a header row with the
/// title plus a status badge, a clean 2x2 grid of label/value rows
/// (Doctor / Specialty / Session / Date & Time), one short supportive
/// sentence, and a single context-aware action button (with an optional
/// secondary "View Details" companion).
///
/// The whole card is tappable from the parent; tap routes to the dedicated
/// [AppointmentDetailScreen] for the full session view.
class _UpcomingSessionCardBody extends StatelessWidget {
  const _UpcomingSessionCardBody({
    required this.session,
    required this.booking,
    required this.doctor,
    required this.payment,
    required this.positionLabel,
    required this.onJoin,
    required this.onViewDetails,
  });

  final SessionDto session;
  final BookingDto? booking;
  final DoctorDto? doctor;
  final PaymentDto? payment;
  final String? positionLabel;
  final VoidCallback onJoin;
  final VoidCallback onViewDetails;

  bool get _paymentCompleted {
    final st = (payment?.status ?? '').toLowerCase().trim();
    return st == 'paid' || st == 'completed' || st == 'success' || st == 'successful';
  }

  bool get _paymentInReview {
    final st = (payment?.status ?? '').toLowerCase().trim();
    return st == 'in_review' || st == 'in-review' || st == 'pending_review' ||
        (payment?.proofSubmittedAt != null && (payment!.proofSubmittedAt ?? '').isNotEmpty && !_paymentCompleted);
  }

  /// True when the session is in a "live or upcoming" state but payment
  /// hasn't yet been completed or submitted for review. Surfaces only on
  /// the status badge — the action row stays Join Now / View Details.
  bool get _awaitingPayment {
    final sessionStatus = session.status.toLowerCase().trim();
    final isLiveOrUpcoming = sessionStatus == 'scheduled' ||
        sessionStatus == 'pending' ||
        sessionStatus == 'in_progress' ||
        sessionStatus == 'requested';
    return isLiveOrUpcoming && !_paymentCompleted && !_paymentInReview;
  }

  bool _isJoinable() {
    final st = session.status.toLowerCase().trim();
    if (st == 'cancelled' || st == 'completed') return false;
    final link = (session.meetingLink ?? '').trim();
    if (link.isEmpty) return false;
    final dt = _SmartAfyaHomeScreenUiState._parseLocal(session.scheduledAt);
    if (dt == null) return st == 'pending' || st == 'scheduled';
    final diff = dt.difference(DateTime.now());
    return diff.inMinutes <= 30 && diff.inMinutes >= -120;
  }

  /// Picks the single supportive sentence shown above the action buttons.
  /// Returns `null` when there's nothing notable to say so the support tile
  /// is hidden entirely (the Join Now button conveys readiness on its own).
  ({String text, IconData icon})? _support({
    required AppLocalizations l10n,
    required DateTime? dt,
    required bool doctorAssigned,
  }) {
    if (!doctorAssigned) {
      return (
        text: l10n.waitingForSpecialist,
        icon: Icons.schedule_rounded,
      );
    }
    if (_paymentInReview) {
      return (
        text: l10n.verifyingPayment,
        icon: Icons.hourglass_top_rounded,
      );
    }
    if (dt != null) {
      final diff = dt.difference(DateTime.now());
      if (diff.inMinutes > 0 && diff.inMinutes <= 30) {
        return (
          text: l10n.sessionStartsInMinutes(diff.inMinutes),
          icon: Icons.notifications_active_outlined,
        );
      }
      if (diff.inHours > 0 && diff.inHours <= 24) {
        return (
          text: l10n.sessionStartsInHours(diff.inHours),
          icon: Icons.notifications_none_rounded,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dt = _SmartAfyaHomeScreenUiState._parseLocal(session.scheduledAt);
    final doctorAssigned = (session.doctorId ?? '').trim().isNotEmpty;
    final joinable = _isJoinable();
    final typeLabel = localizedSessionType(l10n, booking?.sessionType, compact: true);
    final statusInfo = _statusInfo(l10n);
    final support = _support(l10n: l10n, dt: dt, doctorAssigned: doctorAssigned);

    final specialistName = (doctor?.fullName.trim().isNotEmpty == true)
        ? doctor!.fullName.trim()
        : (doctorAssigned ? l10n.specialistAssigned : l10n.awaitingMatch);
    final specialtyLabel = doctor?.specialistLabel ?? l10n.mentalHealthSpecialist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1) Header — title + status pill
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                l10n.upcomingSession,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: SmartAfyaPalette.deepText,
                  fontSize: 16,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            _StatusPill(label: statusInfo.label, color: statusInfo.color),
          ],
        ),
        if ((positionLabel ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            positionLabel!,
            style: const TextStyle(
              color: SmartAfyaPalette.mutedText,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
        const SizedBox(height: 18),

        // 2) Information section — clean 2x2 label/value grid.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _InfoCell(label: l10n.doctorLabel, value: specialistName)),
            const SizedBox(width: 14),
            Expanded(child: _InfoCell(label: l10n.specialtyLabel, value: specialtyLabel)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _InfoCell(label: l10n.sessionLabel, value: typeLabel)),
            const SizedBox(width: 14),
            Expanded(child: _InfoCell(label: l10n.dateTimeLabel, value: formatScheduledDateTime(context, dt))),
          ],
        ),

        // 3) Optional supportive sentence — only rendered for notable
        //    states (waiting for specialist, payment review, imminent
        //    countdown). Hidden otherwise so the action row carries the
        //    weight.
        if (support != null) ...[
          const SizedBox(height: 16),
          _SupportLine(icon: support.icon, text: support.text),
        ],

        const SizedBox(height: 16),

        // 4) Action row — View Details + Join Now. Join Now stays
        //    disabled (greyed out) until the session is within its join
        //    window, then becomes active automatically.
        Row(
          children: [
            Expanded(
              child: _SecondaryCardButton(
                label: l10n.viewDetails,
                onPressed: onViewDetails,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PrimaryCardButton(
                label: l10n.joinNow,
                icon: Icons.video_call_rounded,
                onPressed: joinable ? onJoin : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Maps internal session/payment state to badge styles: Completed (blue),
  /// Confirmed (green), In Review (blue), Pending (amber).
  ({String label, Color color}) _statusInfo(AppLocalizations l10n) {
    final sessionStatus = session.status.toLowerCase().trim();
    if (sessionStatus == 'completed') {
      return (label: l10n.statusCompleted, color: SmartAfyaPalette.primaryBlue);
    }
    if (_paymentCompleted) {
      return (label: l10n.statusConfirmed, color: SmartAfyaPalette.primaryGreen);
    }
    if (_paymentInReview) {
      return (label: l10n.statusInReview, color: SmartAfyaPalette.primaryBlue);
    }
    if (_awaitingPayment) {
      return (label: l10n.statusAwaitingPayment, color: const Color(0xFFE07A1F));
    }
    return (label: l10n.statusPending, color: const Color(0xFFD08600));
  }
}

/// Single label/value cell used inside the upcoming-session info grid.
/// Labels read as small, muted, all-caps-ish meta; values are bold and
/// dark for fast scanning.
class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SmartAfyaPalette.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: SmartAfyaPalette.deepText,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: -0.1,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// One-line, calm supporting sentence shown between the info grid and the
/// action buttons. Uses the brand's soft blue tile so it reads as a hint
/// rather than a warning.
class _SupportLine extends StatelessWidget {
  const _SupportLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SmartAfyaPalette.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: SmartAfyaPalette.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: SmartAfyaPalette.deepText,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                height: 1.3,
                letterSpacing: -0.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary CTA used by the upcoming-session card. Smart Afya blue surface,
/// white label, rounded Material 3 container.
class _PrimaryCardButton extends StatelessWidget {
  const _PrimaryCardButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;

  /// Nullable so the button can render in a disabled (greyed) state — used
  /// by the upcoming-session card to keep "Join Now" visible but inert
  /// until the session enters its join window.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: SmartAfyaPalette.primaryBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            SmartAfyaPalette.primaryBlue.withValues(alpha: 0.30),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        minimumSize: const Size.fromHeight(44),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
      ),
    );
  }
}

/// Ghost / secondary button — white background, subtle hairline border,
/// dark label. Pairs with [_PrimaryCardButton].
class _SecondaryCardButton extends StatelessWidget {
  const _SecondaryCardButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: SmartAfyaPalette.deepText,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: SmartAfyaPalette.deepText.withValues(alpha: 0.14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        minimumSize: const Size.fromHeight(44),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
      ),
    );
  }
}

/// Lightweight empty-state body for the home dashboard's upcoming-session
/// slot. Shown when the patient has no scheduled sessions. The whole card
/// is tappable from the parent and routes into the booking flow.
class _UpcomingSessionEmptyCardBody extends StatelessWidget {
  const _UpcomingSessionEmptyCardBody();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SmartAfyaPalette.softBlue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.event_available_rounded,
            color: SmartAfyaPalette.primaryBlue,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.noUpcomingAppointments,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: SmartAfyaPalette.deepText,
                  fontSize: 15.5,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.bookConsultationToStart,
                style: const TextStyle(
                  color: SmartAfyaPalette.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, color: SmartAfyaPalette.mutedText),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// Legacy home widgets removed during client dashboard redesign.

class _Header extends StatelessWidget {
  const _Header({
    required this.greetingFirstName,
    required this.badgeText,
    required this.badgeIsDoctor,
  });

  final String? greetingFirstName;
  final String badgeText;
  final bool badgeIsDoctor;

  static const _heading = SmartAfyaPalette.deepText;
  static const _subtitle = SmartAfyaPalette.mutedText;
  static const _primaryBlue = SmartAfyaPalette.primaryBlue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = (greetingFirstName ?? '').trim();
    final greeting = first.isEmpty ? l10n.hello : l10n.helloName(first);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _heading,
                  height: 1.05,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (badgeIsDoctor ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.primaryGreen).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _kHairlineBorder),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: badgeIsDoctor ? SmartAfyaPalette.primaryBlue : SmartAfyaPalette.primaryGreen,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Text(
                badgeIsDoctor ? l10n.doctorThankYou : l10n.howAreYouFeeling,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: _subtitle,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6F9),
            shape: BoxShape.circle,
            border: Border.all(color: _kHairlineBorder),
            boxShadow: _kShadowSoft,
          ),
          child: const Icon(Icons.person, color: _primaryBlue, size: 26),
        ),
      ],
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.8,
              fontWeight: FontWeight.w700,
              color: SmartAfyaPalette.mutedText,
            ),
          ),
        ),
      ],
    );
  }
}

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.hasUpcomingSession,
    required this.title,
    required this.subtitle,
    required this.primaryActionText,
    required this.onPrimaryAction,
    this.detailLine,
    this.secondaryActionText,
    this.onSecondaryAction,
    this.onCardTap,
  });

  final bool hasUpcomingSession;
  final String title;
  final String subtitle;
  final String? detailLine;
  final String primaryActionText;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryAction;

  /// Tapping anywhere on the card body (outside the buttons) fires this
  /// callback. Used to open the segmented Upcoming + Completed list when
  /// the card is showing a real upcoming session.
  final VoidCallback? onCardTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    final decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: radius,
      border: Border.all(color: _kHairlineBorder),
      boxShadow: _kShadowSoft,
    );
    const padding = EdgeInsets.fromLTRB(18, 18, 18, 18);
    final body = Padding(
      padding: padding,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: SmartAfyaPalette.deepText,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: SmartAfyaPalette.mutedText,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (detailLine != null && detailLine!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _IconRow(
                icon: Icons.person_pin_circle_rounded,
                iconColor: SmartAfyaPalette.primaryGreen,
                text: detailLine!,
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onPrimaryAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: SmartAfyaPalette.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(primaryActionText, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                if (secondaryActionText != null && onSecondaryAction != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondaryAction,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: SmartAfyaPalette.primaryBlue.withValues(alpha: 0.35)),
                        foregroundColor: SmartAfyaPalette.primaryBlue,
                      ),
                      child: Text(secondaryActionText!, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );

    if (onCardTap == null) {
      return Container(
        width: double.infinity,
        decoration: decoration,
        child: body,
      );
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onCardTap,
          borderRadius: radius,
          child: body,
        ),
      ),
    );
  }
}

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.showJoin,
    required this.onBookConsultation,
    required this.onAppointments,
    required this.onJoinSession,
  });

  final bool showJoin;
  final VoidCallback onBookConsultation;
  final VoidCallback onAppointments;
  final VoidCallback onJoinSession;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cards = <Widget>[
      Expanded(
        child: ActionCard(
          title: l10n.bookConsultation,
          subtitle: l10n.scheduleWithSpecialist,
          icon: Icons.calendar_month_rounded,
          iconBg: const Color(0xFFDAE9F5),
          iconColor: const Color(0xFF1A5FA8),
          onTap: onBookConsultation,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ActionCard(
          title: l10n.myAppointments,
          subtitle: l10n.viewAndManage,
          icon: Icons.calendar_today_rounded,
          iconBg: const Color(0xFFDAE9F5),
          iconColor: const Color(0xFF1A5FA8),
          onTap: onAppointments,
        ),
      ),
      if (showJoin) ...[
        const SizedBox(width: 12),
        Expanded(
          child: ActionCard(
            title: l10n.joinSession,
            subtitle: l10n.joinSessionSubtitle,
            icon: Icons.videocam_rounded,
            iconBg: const Color(0xFFC9EFE4),
            iconColor: const Color(0xFF2E9E72),
            onTap: onJoinSession,
          ),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickActions,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: SmartAfyaPalette.deepText,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 420;
            if (!isNarrow) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: cards);
            }
            // On narrow screens, avoid squeeze — stack in 2 rows.
            return Column(
              children: [
                Row(
                  children: [
                    cards[0],
                    const SizedBox(width: 12),
                    cards[2], // My Appointments (always present)
                  ],
                ),
                if (showJoin) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      cards[4], // Join
                      const Spacer(),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kHairlineBorder),
            boxShadow: _kShadowSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: SmartAfyaPalette.deepText,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.3,
                  fontWeight: FontWeight.w600,
                  color: SmartAfyaPalette.mutedText,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _active = Color(0xFF2E9E72);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: _kShadowNav,
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: _active.withValues(alpha: 0.14),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontWeight: states.contains(WidgetState.selected) ? FontWeight.w900 : FontWeight.w700,
                color: states.contains(WidgetState.selected)
                    ? _active
                    : SmartAfyaPalette.mutedText.withValues(alpha: 0.75),
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                size: 26,
                color: states.contains(WidgetState.selected)
                    ? _active
                    : SmartAfyaPalette.mutedText.withValues(alpha: 0.55),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: context.l10n.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: const Icon(Icons.chat_rounded),
                label: context.l10n.navChat,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_today_outlined),
                selectedIcon: const Icon(Icons.calendar_today_rounded),
                label: context.l10n.navAppointments,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person_rounded),
                label: context.l10n.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressSteps {
  const ProgressSteps({
    required this.hasSubmittedForm,
    required this.hasBookedSession,
    required this.hasMadePayment,
  });

  final bool hasSubmittedForm;
  final bool hasBookedSession;
  final bool hasMadePayment;
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.completed,
    required this.total,
    required this.steps,
    required this.onContinue,
  });

  final int completed;
  final int total;
  final ProgressSteps steps;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.setupYourCare(completed, total);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kHairlineBorder),
        boxShadow: _kShadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: SmartAfyaPalette.deepText,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          _ChecklistRow(
            done: steps.hasSubmittedForm,
            title: l10n.fillHealthForm,
          ),
          const SizedBox(height: 10),
          _ChecklistRow(
            done: steps.hasBookedSession,
            title: l10n.bookSession,
          ),
          const SizedBox(height: 10),
          _ChecklistRow(
            done: steps.hasMadePayment,
            title: l10n.makePayment,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: SmartAfyaPalette.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(l10n.continueAction, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.done, required this.title});

  final bool done;
  final String title;

  @override
  Widget build(BuildContext context) {
    final icon = done ? Icons.check_circle : Icons.radio_button_unchecked;
    final color = done ? Colors.green : Colors.grey;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: SmartAfyaPalette.deepText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key, this.initialSessionId});

  /// Optional. When provided, the screen loads this specific session's
  /// payment details instead of auto-picking the next upcoming session.
  final String? initialSessionId;

  @override
  Widget build(BuildContext context) {
    return _PaymentsScreenBody(initialSessionId: initialSessionId);
  }
}

class _PaymentsScreenBody extends StatefulWidget {
  const _PaymentsScreenBody({this.initialSessionId});

  final String? initialSessionId;

  @override
  State<_PaymentsScreenBody> createState() => _PaymentsScreenBodyState();
}

class _PaymentsScreenBodyState extends State<_PaymentsScreenBody> {
  final _api = ApiService();
  bool _loading = true;
  bool _uploadingProof = false;
  String? _error;
  SessionDto? _upcoming;
  PaymentDto? _payment;

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
      SessionDto? s;
      final targetId = (widget.initialSessionId ?? '').trim();
      if (targetId.isNotEmpty) {
        s = await _api.fetchSessionById(targetId).timeout(const Duration(seconds: 8));
      } else {
        final sessions = await _api.fetchSessions().timeout(const Duration(seconds: 8));
        final now = DateTime.now();
        final upcoming = sessions
            .map((x) => (s: x, dt: _SmartAfyaHomeScreenUiState._parseLocal(x.scheduledAt)))
            .where((x) => x.dt != null && x.dt!.isAfter(now.subtract(const Duration(hours: 2))))
            .toList()
          ..sort((a, b) => a.dt!.compareTo(b.dt!));
        s = upcoming.isEmpty ? null : upcoming.first.s;
      }
      final p = s == null ? null : await _api.fetchPaymentForSession(s.id).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _upcoming = s;
        _payment = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load payment details. Pull to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmartAfyaPalette.scaffoldBg,
      appBar: AppBar(
        title: const Text('Payments', style: TextStyle(fontWeight: FontWeight.w900)),
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
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: [
                        _paymentSummaryCard(context),
                        const SizedBox(height: 14),
                        _paymentProofCard(context),
                        const SizedBox(height: 14),
                        _paymentMethodsCard(context),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _paymentSummaryCard(BuildContext context) {
    final s = _upcoming;
    final p = _payment;
    final status = (p?.status ?? 'awaiting_payment').trim();
    final amount = p?.amount;
    final when = s?.scheduledAt;
    final instructions = (p?.instructionsText ?? '').trim();

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
          const Text('Payment summary', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
          const SizedBox(height: 10),
          Text('Status: $status', style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Amount: ${amount == null ? '— (set by admin)' : 'TZS ${amount.toStringAsFixed(0)}'}',
            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Session: ${when == null || when.trim().isEmpty ? '—' : when}',
            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700),
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(instructions, style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w700, height: 1.3)),
          ],
        ],
      ),
    );
  }

  Widget _paymentProofCard(BuildContext context) {
    final p = _payment;
    final ready = paymentReadyForBooking(p);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFE8F8F0) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ready ? const Color(0xFFB8E6C8) : const Color(0xFFE4EEF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ready ? 'Payment proof received' : 'Upload payment proof',
            style: const TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText),
          ),
          const SizedBox(height: 8),
          Text(
            ready
                ? 'Admin will verify and schedule your appointment. You can go back and submit your booking if you have not already.'
                : 'Pay via mobile money or bank, then upload a screenshot or receipt (JPG, PNG, or PDF).',
            style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w600, height: 1.35),
          ),
          if (!ready) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_uploadingProof || p == null) ? null : _uploadProof,
              style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
              icon: _uploadingProof
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                _uploadingProof ? 'Uploading…' : 'Upload proof',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadProof() async {
    final payment = _payment;
    if (payment == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment record not loaded yet. Pull to refresh.')),
      );
      return;
    }

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }
    if (bytes.length > 4 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is too large. Please use an image under 4 MB.')),
      );
      return;
    }

    setState(() => _uploadingProof = true);
    try {
      final updated = await _api.submitPaymentProof(
        paymentId: payment.id,
        proofBase64: base64Encode(bytes),
        filename: file.name,
      );
      if (!mounted) return;
      setState(() => _payment = updated);
      if (paymentReadyForBooking(updated)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment proof submitted. You can complete your booking now.')),
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = messageFromDioException(e) ?? 'Failed to upload proof.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload proof.')),
      );
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  Widget _paymentMethodsCard(BuildContext context) {
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
          const Text('Pay using', style: TextStyle(fontWeight: FontWeight.w900, color: SmartAfyaPalette.deepText)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _showMobileMoneySheet(context),
            style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
            icon: const Icon(Icons.phone_iphone_rounded),
            label: const Text('Mobile money (Lipa Namba)', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showBankSheet(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE4EEF7)),
              foregroundColor: SmartAfyaPalette.deepText,
            ),
            icon: const Icon(Icons.account_balance_rounded),
            label: const Text('Bank payment', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await NotificationService.showPaymentRequest(
                title: 'Payment request',
                body: 'Please complete payment to confirm your consultation.',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment request notification triggered.')),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE4EEF7)),
              foregroundColor: SmartAfyaPalette.primaryBlue,
            ),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Request payment push', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showMobileMoneySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Mobile money (Lipa Namba)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                const Text(
                  'Pay using your provider’s menu and enter the Lipa Namba shown below.',
                  style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
                ),
                const SizedBox(height: 12),
                _kv('Lipa Namba', '123456'),
                _kv('Account name', 'Smart Afya'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await NotificationService.showPaymentRequest(
                      title: 'Payment request sent',
                      body: 'Complete Mobile Money payment using Lipa Namba 123456.',
                    );
                  },
                  style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                  child: const Text('Send payment prompt', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBankSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Bank payment', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                const Text(
                  'Transfer to the account below. Use your Session ID as the reference if available.',
                  style: TextStyle(color: SmartAfyaPalette.mutedText, height: 1.35),
                ),
                const SizedBox(height: 12),
                _kv('Bank', 'NMB'),
                _kv('Account name', 'Smart Afya'),
                _kv('Account number', '0000000000'),
                _kv('Reference', _upcoming?.id ?? '—'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await NotificationService.showPaymentRequest(
                      title: 'Bank payment',
                      body: 'Please complete bank transfer and keep your receipt.',
                    );
                  },
                  style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                  child: const Text('I will pay via bank', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: SmartAfyaPalette.mutedText, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Text(v, style: const TextStyle(color: SmartAfyaPalette.deepText, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _isDoctor = false;
  bool _isClient = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _api.fetchCurrentUser().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _isDoctor = user.isDoctor;
        _isClient = user.isClient;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load profile (${e.response?.statusCode ?? 'network error'}).';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: SmartAfyaPalette.primaryBlue)),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadRole,
                  style: FilledButton.styleFrom(backgroundColor: SmartAfyaPalette.primaryBlue),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_isDoctor) {
      return DoctorProfileScreen(onRefreshParent: _loadRole);
    }
    if (_isClient) {
      return const ClientProfileScreen();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile screen')),
    );
  }
}


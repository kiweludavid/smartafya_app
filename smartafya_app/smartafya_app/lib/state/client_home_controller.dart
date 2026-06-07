import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';

enum ClientHomeMode {
  startYourCare,
  setupYourCare,
  upcomingSession,
}

class ClientHomeViewState {
  const ClientHomeViewState({
    required this.isLoading,
    required this.errorMessage,
    required this.bookings,
    required this.sessions,
    required this.careActions,
    required this.paymentForUpcoming,
    required this.myFeedback,
    required this.upcomingSession,
    required this.upcomingSessions,
    required this.paymentsBySessionId,
    required this.doctorsById,
    required this.homeMode,
    required this.completedSessionNeedingFeedback,
    required this.sessionCreditBalance,
    required this.latestMissedSession,
  });

  final bool isLoading;
  final String? errorMessage;

  final List<BookingDto> bookings;
  final List<SessionDto> sessions;
  final CareActionsDto? careActions;
  final PaymentDto? paymentForUpcoming;
  final List<FeedbackDto> myFeedback;

  /// First session in [upcomingSessions] (kept for backwards compatibility).
  final SessionDto? upcomingSession;

  /// All upcoming sessions for the patient, sorted by scheduled time ascending.
  /// "Upcoming" includes sessions starting up to 2 hours ago so a session that
  /// has just begun does not vanish from the home dashboard.
  final List<SessionDto> upcomingSessions;

  /// Payment records keyed by session id, populated for every entry in
  /// [upcomingSessions] (entry missing = no payment record yet).
  final Map<String, PaymentDto> paymentsBySessionId;

  /// Doctor directory keyed by doctor id, used to render specialist name
  /// and specialty on the home upcoming card and the appointments lists.
  final Map<String, DoctorDto> doctorsById;

  final ClientHomeMode homeMode;
  final SessionDto? completedSessionNeedingFeedback;

  /// Wallet credit from first-miss policy (`session_credit_balance` on `/users/me`).
  final double sessionCreditBalance;

  /// Most recent missed (`no_show`) session for the home banner (when recent).
  final SessionDto? latestMissedSession;

  factory ClientHomeViewState.initial() => const ClientHomeViewState(
        isLoading: true,
        errorMessage: null,
        bookings: <BookingDto>[],
        sessions: <SessionDto>[],
        careActions: null,
        paymentForUpcoming: null,
        myFeedback: <FeedbackDto>[],
        upcomingSession: null,
        upcomingSessions: <SessionDto>[],
        paymentsBySessionId: <String, PaymentDto>{},
        doctorsById: <String, DoctorDto>{},
        homeMode: ClientHomeMode.startYourCare,
        completedSessionNeedingFeedback: null,
        sessionCreditBalance: 0,
        latestMissedSession: null,
      );

  ClientHomeViewState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<BookingDto>? bookings,
    List<SessionDto>? sessions,
    CareActionsDto? careActions,
    PaymentDto? paymentForUpcoming,
    List<FeedbackDto>? myFeedback,
    SessionDto? upcomingSession,
    List<SessionDto>? upcomingSessions,
    Map<String, PaymentDto>? paymentsBySessionId,
    Map<String, DoctorDto>? doctorsById,
    ClientHomeMode? homeMode,
    SessionDto? completedSessionNeedingFeedback,
    double? sessionCreditBalance,
    SessionDto? latestMissedSession,
    bool replaceCreditAndMissed = false,
  }) {
    return ClientHomeViewState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      bookings: bookings ?? this.bookings,
      sessions: sessions ?? this.sessions,
      careActions: careActions ?? this.careActions,
      paymentForUpcoming: paymentForUpcoming ?? this.paymentForUpcoming,
      myFeedback: myFeedback ?? this.myFeedback,
      upcomingSession: upcomingSession ?? this.upcomingSession,
      upcomingSessions: upcomingSessions ?? this.upcomingSessions,
      paymentsBySessionId: paymentsBySessionId ?? this.paymentsBySessionId,
      doctorsById: doctorsById ?? this.doctorsById,
      homeMode: homeMode ?? this.homeMode,
      completedSessionNeedingFeedback: completedSessionNeedingFeedback ?? this.completedSessionNeedingFeedback,
      sessionCreditBalance: replaceCreditAndMissed
          ? (sessionCreditBalance ?? 0)
          : (sessionCreditBalance ?? this.sessionCreditBalance),
      latestMissedSession: replaceCreditAndMissed
          ? latestMissedSession
          : (latestMissedSession ?? this.latestMissedSession),
    );
  }
}

class ClientHomeController extends ChangeNotifier {
  ClientHomeController({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  ClientHomeViewState _state = ClientHomeViewState.initial();
  ClientHomeViewState get state => _state;

  Future<void> load() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _api.fetchMyBookings(),
        _api.fetchSessions(),
        _api.fetchCareActions(),
        _api.fetchMyFeedback(),
        _api.fetchCurrentUser(),
      ]);

      final bookings = (results[0] as List).cast<BookingDto>();
      final sessions = (results[1] as List).cast<SessionDto>();
      final careActions = results[2] as CareActionsDto;
      final myFeedback = (results[3] as List).cast<FeedbackDto>();
      final me = results[4] as CurrentUserDto;

      // Debug log: show every session returned for this client + the
      // verdict of the upcoming-session resolver. Useful when an admin
      // schedules a session and it doesn't surface on the home card.
      assert(() {
        debugPrint('[ClientHomeController] /sessions returned ${sessions.length} session(s):');
        for (final s in sessions) {
          debugPrint(
            '  • id=${s.id} status="${s.status}" scheduledAt=${s.scheduledAt} '
            'doctorId=${s.doctorId ?? "-"} bookingId=${s.bookingId}',
          );
        }
        return true;
      }());

      final upcomings = _findUpcomingSessions(sessions);
      final upcoming = upcomings.isEmpty ? null : upcomings.first;

      final latestMissed = _findLatestMissedSessionForBanner(sessions);

      assert(() {
        debugPrint(
          '[ClientHomeController] _findUpcomingSessions kept ${upcomings.length}/${sessions.length}',
        );
        return true;
      }());

      final paymentsBySessionId = <String, PaymentDto>{};
      if (upcomings.isNotEmpty) {
        final paymentResults = await Future.wait(
          upcomings.map((s) async {
            try {
              final p = await _api.fetchPaymentForSession(s.id);
              return MapEntry<String, PaymentDto?>(s.id, p);
            } catch (_) {
              return MapEntry<String, PaymentDto?>(s.id, null);
            }
          }),
        );
        for (final entry in paymentResults) {
          final p = entry.value;
          if (p != null) paymentsBySessionId[entry.key] = p;
        }
      }
      final payment = upcoming == null ? null : paymentsBySessionId[upcoming.id];

      // Hydrate the specialist directory only when at least one upcoming
      // session already has a doctor assigned. This keeps brand-new accounts
      // (no scheduled sessions) free of an extra round-trip while still
      // letting the home card / appointment list show specialist name and
      // specialty for confirmed sessions.
      Map<String, DoctorDto> doctorsById = _state.doctorsById;
      final needsDoctorLookup = upcomings.any(
            (s) => (s.doctorId ?? '').trim().isNotEmpty,
          ) ||
          ((latestMissed?.doctorId ?? '').trim().isNotEmpty);
      if (needsDoctorLookup) {
        try {
          final doctors = await _api.fetchDoctors();
          doctorsById = {for (final d in doctors) d.id: d};
        } catch (_) {
          // Non-fatal: card falls back to "Specialist assigned".
        }
      }

      final derived = _deriveHomeMode(
        bookings: bookings,
        upcoming: upcoming,
      );

      final completedNeedsFeedback = _findCompletedSessionNeedingFeedback(
        sessions: sessions,
        feedback: myFeedback,
      );

      _state = _state.copyWith(
        isLoading: false,
        errorMessage: null,
        bookings: bookings,
        sessions: sessions,
        careActions: careActions,
        myFeedback: myFeedback,
        upcomingSession: upcoming,
        upcomingSessions: upcomings,
        paymentsBySessionId: paymentsBySessionId,
        doctorsById: doctorsById,
        paymentForUpcoming: payment,
        homeMode: derived,
        completedSessionNeedingFeedback: completedNeedsFeedback,
        sessionCreditBalance: me.sessionCreditBalance,
        latestMissedSession: latestMissed,
        replaceCreditAndMissed: true,
      );
      notifyListeners();
      unawaited(
        NotificationService.syncUpcomingSessionReminders(
          sessionId: upcoming?.id,
          scheduledAtIso: upcoming?.scheduledAt,
        ),
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load your home data. Pull to retry.',
      );
      notifyListeners();
    }
  }

  /// All "live or upcoming" sessions for the patient, sorted by scheduled
  /// time ascending. We exclude cancelled/completed/no-show sessions. We
  /// **include** sessions that started up to 2 hours ago so the home
  /// dashboard does not silently drop a session the moment its scheduled
  /// time passes — the user can still see (and pay for / join) it during
  /// its grace window.
  ///
  /// Sessions with an active status but a missing `scheduled_at` are still
  /// surfaced (sorted last). This is defensive: we'd rather show a card
  /// with a "TBD" date than silently hide a freshly-scheduled session
  /// because of a brief data race where the time hasn't been written yet.
  static List<SessionDto> _findUpcomingSessions(List<SessionDto> sessions) {
    final now = DateTime.now();
    final cutoffPast = now.subtract(const Duration(hours: 2));
    final dated = <(SessionDto, DateTime)>[];
    final undated = <SessionDto>[];

    for (final s in sessions) {
      final st = s.status.toLowerCase().trim();
      if (st == 'cancelled' ||
          st == 'completed' ||
          st == 'no_show' ||
          st == 'no-show' ||
          st == 'done' ||
          st == 'finished') {
        assert(() {
          debugPrint('  ✗ drop ${s.id}: status="$st" (terminal)');
          return true;
        }());
        continue;
      }

      final dt = _parseLocal(s.scheduledAt);
      if (dt == null) {
        assert(() {
          debugPrint(
            '  ↪ keep ${s.id}: status="$st" scheduledAt missing (sorted last)',
          );
          return true;
        }());
        undated.add(s);
        continue;
      }

      if (dt.isBefore(cutoffPast)) {
        assert(() {
          debugPrint(
            '  ✗ drop ${s.id}: status="$st" scheduledAt=$dt before cutoff $cutoffPast',
          );
          return true;
        }());
        continue;
      }

      assert(() {
        debugPrint('  ✓ keep ${s.id}: status="$st" scheduledAt=$dt');
        return true;
      }());
      dated.add((s, dt));
    }

    dated.sort((a, b) => a.$2.compareTo(b.$2));
    return [
      ...dated.map((c) => c.$1),
      ...undated,
    ];
  }

  static ClientHomeMode _deriveHomeMode({
    required List<BookingDto> bookings,
    required SessionDto? upcoming,
  }) {
    if (upcoming != null) return ClientHomeMode.upcomingSession;
    if (bookings.isEmpty) return ClientHomeMode.startYourCare;

    final hasIncomplete = bookings.any((b) {
      final descOk = (b.mentalHealthDescription ?? '').trim().isNotEmpty;
      final consentOk = b.consentGiven == true;
      return !(descOk && consentOk);
    });
    return hasIncomplete ? ClientHomeMode.setupYourCare : ClientHomeMode.setupYourCare;
  }

  /// Latest `no_show` session with a scheduled time in the last 14 days — used
  /// for the home "missed session" banner (not shown when there is nothing recent).
  static SessionDto? _findLatestMissedSessionForBanner(List<SessionDto> sessions) {
    final missed = sessions.where((s) {
      final st = s.status.toLowerCase().trim();
      return st == 'no_show' || st == 'no-show';
    }).toList();
    if (missed.isEmpty) return null;

    missed.sort((a, b) {
      final ta = _parseLocal(a.scheduledAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = _parseLocal(b.scheduledAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    final latest = missed.first;
    final when = _parseLocal(latest.scheduledAt);
    if (when == null) return latest;
    if (DateTime.now().difference(when) > const Duration(days: 14)) return null;
    return latest;
  }

  static SessionDto? _findCompletedSessionNeedingFeedback({
    required List<SessionDto> sessions,
    required List<FeedbackDto> feedback,
  }) {
    final feedbackSessionIds = feedback.map((f) => f.sessionId).toSet();
    final completed = sessions
        .where((s) {
          final st = s.status.toLowerCase().trim();
          final isCompleted = st == 'completed' || st == 'done' || st == 'finished';
          return isCompleted && !feedbackSessionIds.contains(s.id);
        })
        .map((s) => (s: s, dt: _parseLocal(s.scheduledAt) ?? DateTime.fromMillisecondsSinceEpoch(0)))
        .toList()
      ..sort((a, b) => b.dt.compareTo(a.dt));
    return completed.isEmpty ? null : completed.first.s;
  }

  static DateTime? _parseLocal(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }
}


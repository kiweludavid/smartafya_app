import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: payments, admin, chat, and **session reminders**
/// (1h and 15m before the next upcoming session).
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _tzReady = false;
  static int _nextId = 1000;
  static String? _reminderSessionId;

  static int _reminderId(String sessionId, int slot) =>
      (sessionId.hashCode.abs() % 200000000) + slot;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);

    try {
      await _plugin.initialize(settings: initSettings);
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }

    await _initTimezone();
  }

  static Future<void> _initTimezone() async {
    if (_tzReady) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _tzReady = true;
    } catch (e) {
      debugPrint('Timezone init failed (session reminders disabled): $e');
    }
  }

  /// Schedules two reminders for the **nearest** upcoming session. Cancels
  /// reminders tied to a previously scheduled session id.
  static Future<void> syncUpcomingSessionReminders({
    required String? sessionId,
    required String? scheduledAtIso,
  }) async {
    await init();
    await _initTimezone();
    if (!_tzReady || sessionId == null || sessionId.isEmpty) {
      await cancelSessionReminders();
      return;
    }

    final startLocal = DateTime.tryParse((scheduledAtIso ?? '').trim())?.toLocal();
    if (startLocal == null) {
      await cancelSessionReminders();
      return;
    }

    if (_reminderSessionId != null && _reminderSessionId != sessionId) {
      await cancelSessionRemindersFor(_reminderSessionId!);
    }
    _reminderSessionId = sessionId;
    await cancelSessionRemindersFor(sessionId);

    final now = tz.TZDateTime.now(tz.local);
    final atOneHour = tz.TZDateTime.from(startLocal, tz.local).subtract(const Duration(hours: 1));
    final atFifteen = tz.TZDateTime.from(startLocal, tz.local).subtract(const Duration(minutes: 15));

    await _scheduleIfFuture(
      id: _reminderId(sessionId, 1),
      when: atOneHour,
      title: 'Session in 1 hour',
      body: 'Your Smart Afya consultation starts soon.',
      now: now,
    );
    await _scheduleIfFuture(
      id: _reminderId(sessionId, 2),
      when: atFifteen,
      title: 'Session in 15 minutes',
      body: 'Join from the home screen when you are ready.',
      now: now,
    );
  }

  static Future<void> _scheduleIfFuture({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
    required tz.TZDateTime now,
  }) async {
    if (!when.isAfter(now)) return;
    try {
      const android = AndroidNotificationDetails(
        'session_reminders',
        'Session reminders',
        channelDescription: 'Consultation start reminders',
        importance: Importance.high,
        priority: Priority.high,
      );
      final details = NotificationDetails(android: android);
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Schedule reminder failed: $e');
    }
  }

  static Future<void> cancelSessionRemindersFor(String sessionId) async {
    try {
      await _plugin.cancel(id: _reminderId(sessionId, 1));
      await _plugin.cancel(id: _reminderId(sessionId, 2));
    } catch (e) {
      debugPrint('Cancel reminders failed: $e');
    }
  }

  static Future<void> cancelSessionReminders() async {
    if (_reminderSessionId != null) {
      await cancelSessionRemindersFor(_reminderSessionId!);
      _reminderSessionId = null;
    }
  }

  static Future<void> _show({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
  }) async {
    try {
      final android = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      final details = NotificationDetails(android: android);
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Notification show failed: $e');
    }
  }

  static Future<void> showPaymentRequest({
    required String title,
    required String body,
  }) async {
    await _show(
      channelId: 'payments',
      channelName: 'Payments',
      channelDescription: 'Payment requests and updates',
      title: title,
      body: body,
    );
  }

  static Future<void> physicalWorkflow({
    required String title,
    required String body,
  }) async {
    await _show(
      channelId: 'physical_workflow',
      channelName: 'Physical visits',
      channelDescription: 'Physical session coordination',
      title: title,
      body: body,
    );
  }

  static Future<void> adminOps({
    required String title,
    required String body,
  }) async {
    await _show(
      channelId: 'admin_ops',
      channelName: 'Admin',
      channelDescription: 'Administrative alerts',
      title: title,
      body: body,
    );
  }

  static Future<void> chatMessage({
    required String title,
    required String body,
  }) async {
    await _show(
      channelId: 'chat_messages',
      channelName: 'Messages',
      channelDescription: 'Secure care team chat',
      title: title,
      body: body,
    );
  }
}

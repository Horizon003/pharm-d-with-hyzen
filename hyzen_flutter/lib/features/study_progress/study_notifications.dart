import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Device-local Android/iOS alarms. They are not Firebase messages and do not
/// require the app to stay open or the phone to be online.
class StudyNotificationScheduler {
  StudyNotificationScheduler._();
  static final instance = StudyNotificationScheduler._();
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  void Function(String route)? onOpen;
  String? _pendingRoute;

  int idFor(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash = (hash ^ unit) * 16777619 & 0x7fffffff;
    }
    return hash;
  }

  Future<void> initialize() => _ready ??= _initialize();

  Future<void> _initialize() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to UTC for absolute instants if platform timezone is missing.
    }
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestSoundPermission: false,
            requestAlertPermission: false,
            requestBadgePermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          _open(response.payload);
        },
      );
      final launched = await _plugin.getNotificationAppLaunchDetails();
      if (launched?.didNotificationLaunchApp == true) {
        _open(launched?.notificationResponse?.payload);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Notification setup unavailable: $error');
    }
  }

  void bindOpenHandler(void Function(String) handler) {
    onOpen = handler;
    final pending = _pendingRoute;
    if (pending != null) {
      _pendingRoute = null;
      handler(pending);
    }
  }

  void _open(String? payload) {
    final route = payload?.startsWith('/study-') == true
        ? payload! : '/study-goals';
    if (onOpen == null) {
      _pendingRoute = route;
    } else {
      onOpen!(route);
    }
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true,
          sound: true) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancel(String key) async {
    if (kIsWeb) return;
    await initialize();
    try {
      for (var i = 0; i < 7; i++) {
        await _plugin.cancel(idFor('$key:$i'));
      }
    } catch (_) {}
  }

  Future<void> schedule({
    required String key,
    required String title,
    required DateTime due,
    String repeat = 'none',
    String route = '/study-goals',
    int leadMinutes = 0,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await cancel(key);
    try {
      final now = DateTime.now();
      final notice = const NotificationDetails(android: AndroidNotificationDetails(
        'hyzen_study_v1', 'Study and task reminders',
        channelDescription: 'Your scheduled study goals and tasks',
        importance: Importance.high, priority: Priority.high,
      ), iOS: DarwinNotificationDetails());
      Future<void> put(int slot, DateTime time, DateTimeComponents? match) async {
        final when = tz.TZDateTime.from(time, tz.local);
        await _plugin.zonedSchedule(idFor('$key:$slot'),
          'PHARM D WITH HYZEN', title, when, notice,
          payload: route,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: match,
        );
      }
      if (repeat == 'weekdays') {
        for (var weekday = 1; weekday <= 5; weekday++) {
          var day = now;
          var delta = (weekday - day.weekday + 7) % 7;
          var at = DateTime(day.year, day.month, day.day + delta,
              due.hour, due.minute).subtract(Duration(minutes: leadMinutes));
          if (!at.isAfter(now)) {
            delta += 7;
            at = DateTime(day.year, day.month, day.day + delta,
                due.hour, due.minute).subtract(Duration(minutes: leadMinutes));
          }
          await put(weekday, at, DateTimeComponents.dayOfWeekAndTime);
        }
      } else if (repeat == 'daily' || repeat == 'weekly') {
        var at = DateTime(now.year, now.month, now.day,
            due.hour, due.minute).subtract(Duration(minutes: leadMinutes));
        if (repeat == 'weekly') {
          final shift = (due.weekday - now.weekday + 7) % 7;
          at = at.add(Duration(days: shift));
        }
        if (!at.isAfter(now)) {
          at = at.add(Duration(days: repeat == 'daily' ? 1 : 7));
        }
        await put(0, at, repeat == 'daily'
            ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime);
      } else {
        final at = due.subtract(Duration(minutes: leadMinutes));
        if (at.isAfter(now)) await put(0, at, null);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Could not schedule reminder: $error');
    }
  }
}

// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../notifications/notifications_screen.dart';
import 'study_notifications.dart';
import 'study_session.dart';
import 'study_cloud.dart';
import 'engagement_reminders.dart';

String studyDayKey(DateTime d) =>
    d.year.toString().padLeft(4, '0') +
    '-' +
    d.month.toString().padLeft(2, '0') +
    '-' +
    d.day.toString().padLeft(2, '0');

String formatStudyTime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds ~/ 60) % 60;
  final s = seconds % 60;
  return h > 0
      ? '$h h ' + m.toString().padLeft(2, '0') + ' m'
      : '$m m ' + s.toString().padLeft(2, '0') + ' s';
}

class StudyStats {
  static int weekSeconds(Map<String, int> days, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(
      now.weekday,
      (i) => studyDayKey(monday.add(Duration(days: i))),
    ).fold(0, (sum, day) => sum + (days[day] ?? 0));
  }

  static int streak(Map<String, int> days, DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if ((days[studyDayKey(day)] ?? 0) < 900) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var count = 0;
    while ((days[studyDayKey(day)] ?? 0) >= 900) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  static int bestStreak(Map<String, int> days, [DateTime? now]) {
    final dates =
        days.keys
            .where(
              (k) =>
                  (days[k] ?? 0) >= 900 &&
                  k.compareTo(studyDayKey(now ?? DateTime.now())) <= 0,
            )
            .toList()
          ..sort();
    DateTime? last;
    var current = 0;
    var best = 0;
    for (final value in dates) {
      final day = DateTime.tryParse(value);
      if (day == null) continue;
      current =
          last != null && day == DateTime(last.year, last.month, last.day + 1)
          ? current + 1
          : 1;
      if (current > best) best = current;
      last = day;
    }
    return best;
  }

  static List<String> recentBreaks(Map<String, int> days, [DateTime? now]) {
    final dates =
        days.keys
            .where(
              (k) =>
                  (days[k] ?? 0) >= 900 &&
                  k.compareTo(studyDayKey(now ?? DateTime.now())) <= 0,
            )
            .toList()
          ..sort();
    final breaks = <String>[];
    for (var i = dates.length - 1; i > 0; i--) {
      final newer = DateTime.tryParse(dates[i]);
      final older = DateTime.tryParse(dates[i - 1]);
      if (newer == null || older == null) continue;
      final skipped = newer.difference(older).inDays - 1;
      if (skipped > 0) breaks.add('$skipped missed day(s) before ' + dates[i]);
    }
    return breaks;
  }
}

class StudyTask {
  const StudyTask(
    this.id,
    this.title, {
    this.due,
    this.done = false,
    this.alerted = false,
    this.kind = 'task',
    this.category = 'General',
    this.priority = 'medium',
    this.repeat = 'none',
    this.estimatedMinutes = 30,
    this.leadMinutes = 0,
    this.enabled = true,
    this.weekdays = const [],
    this.extraAlerts = 0,
    this.quiet = true,
    this.until,
  });
  final String id;
  final String title;
  final DateTime? due;
  final bool done;
  final bool alerted;
  final bool enabled;
  final List<int> weekdays;
  final int extraAlerts;
  final bool quiet;
  final DateTime? until;
  final String kind, category, priority, repeat;
  final int estimatedMinutes, leadMinutes;

  StudyTask change({bool? done, bool? alerted, bool? enabled}) => StudyTask(
    id,
    title,
    due: due,
    done: done ?? this.done,
    alerted: alerted ?? this.alerted,
    enabled: enabled ?? this.enabled,
    kind: kind,
    category: category,
    priority: priority,
    repeat: repeat,
    estimatedMinutes: estimatedMinutes,
    leadMinutes: leadMinutes,
    weekdays: weekdays,
    extraAlerts: extraAlerts,
    quiet: quiet,
    until: until,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'due': due?.toIso8601String(),
    'done': done,
    'alerted': alerted,
    'enabled': enabled,
    'weekdays': weekdays,
    'extraAlerts': extraAlerts,
    'quiet': quiet,
    'until': until?.toIso8601String(),
    'kind': kind,
    'category': category,
    'priority': priority,
    'repeat': repeat,
    'estimatedMinutes': estimatedMinutes,
    'leadMinutes': leadMinutes,
  };

  factory StudyTask.fromJson(Map<String, dynamic> map) => StudyTask(
    (map['id'] ?? '').toString(),
    (map['title'] ?? '').toString(),
    due: DateTime.tryParse((map['due'] ?? '').toString()),
    done: map['done'] == true,
    alerted: map['alerted'] == true,
    kind: (map['kind'] ?? 'task').toString(),
    category: (map['category'] ?? 'General').toString(),
    priority: (map['priority'] ?? 'medium').toString(),
    repeat: (map['repeat'] ?? 'none').toString(),
    estimatedMinutes: ((map['estimatedMinutes'] as num?)?.toInt() ?? 30)
        .clamp(1, 1440)
        .toInt(),
    leadMinutes: ((map['leadMinutes'] as num?)?.toInt() ?? 0)
        .clamp(0, 120)
        .toInt(),
    enabled: map['enabled'] != false,
    weekdays: (map['weekdays'] as List? ?? [])
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toList(),
    extraAlerts: ((map['extraAlerts'] as num?)?.toInt() ?? 0).clamp(0, 2),
    quiet: map['quiet'] != false,
    until: DateTime.tryParse((map['until'] ?? '').toString()),
  );
}

class StudyTracker extends ChangeNotifier with WidgetsBindingObserver {
  StudyTracker(
    this.prefs,
    this.storageKey,
    this.onReminder, {
    DateTime Function()? clock,
    int Function()? elapsedMs,
    this.scheduleDevice = true,
  }) : clock = clock ?? DateTime.now {
    _watch.start();
    _elapsedMs = elapsedMs ?? (() => _watch.elapsedMilliseconds);
    _load();
    WidgetsBinding.instance.addObserver(this);
    _checkReminders();
    _manageTicker();
    // Restore alarms when the user returns after an update or device reboot.
    for (final task in _tasks) {
      if (task.enabled && !task.done && task.due != null) {
        unawaited(_scheduleDevice(task));
      }
    }
    refreshEngagementReminders();
  }

  final SharedPreferences prefs;
  final String storageKey;
  final void Function(StudyTask) onReminder;
  final Map<String, int> _days = {};
  final List<StudyTask> _tasks = [];
  final DateTime Function() clock;
  final bool scheduleDevice;
  final Stopwatch _watch = Stopwatch();
  late final int Function() _elapsedMs;
  int _lastMs = 0;
  String? _session;
  DateTime? _interaction;
  bool _disposed = false;
  final List<StudyEvent> _events = [];
  final Set<String> _completed = {};
  final Map<String, int> _legacy = {};
  Future<void> _writes = Future.value();
  String? saveError;
  List<StudyEvent> get events => List.unmodifiable(_events);
  List<StudyEvent> get pendingEvents =>
      _events.where((e) => !e.synced).toList();
  List<String> get completedSessions => List.unmodifiable(_completed);
  bool get hasSession => _session != null;
  Future<void> flush() => _writes;
  void acknowledge(Set<String> ids) {
    for (var i = 0; i < _events.length; i++) {
      if (ids.contains(_events[i].id)) _events[i] = _events[i].acknowledge();
    }
    _save();
  }

  void interaction() {
    _interaction = clock();
  }

  void _recompute() {
    _days
      ..clear()
      ..addAll(_legacy);
    for (final e in sessionTotals(_events).entries) {
      _days[e.key] = (_days[e.key] ?? 0) + e.value;
    }
  }

  DateTime? _lastTick;
  Timer? _timer;
  int _elapsedTicks = 0;
  bool running = false;
  int dailyGoal = 120;
  int weeklyGoal = 840;
  int customGoal = 90;
  bool goalAlerts = false, streakAlerts = false;
  String? _engagementState;
  Future<void> _engagementWrite = Future.value();

  Future<bool> setEngagementReminders({bool? goals, bool? streaks}) async {
    if ((goals == true || streaks == true) &&
        !await StudyNotificationScheduler.instance.requestPermission()) {
      return false;
    }
    if (_disposed) return false;
    goalAlerts = goals ?? goalAlerts;
    streakAlerts = streaks ?? streakAlerts;
    _save();
    refreshEngagementReminders(force: true);
    notifyListeners();
    await _engagementWrite;
    return true;
  }

  void refreshEngagementReminders({bool force = false}) {
    if (!scheduleDevice || _disposed) return;
    final now = clock();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final qualified = (_days[studyDayKey(yesterday)] ?? 0) >= 900;
    final state =
        '${studyDayKey(now)}:$goalAlerts:$streakAlerts:$dailyGoal:'
        '${todaySeconds >= dailyGoal * 60}:${todaySeconds >= 900}:$qualified';
    if (!force && state == _engagementState) return;
    _engagementState = state;
    _engagementWrite = StudyNotificationScheduler.instance.engagement(
      '$storageKey:engagement',
      engagementReminders(
        now: now,
        goals: goalAlerts,
        streaks: streakAlerts,
        todaySeconds: todaySeconds,
        dailyGoalMinutes: dailyGoal,
        yesterdayQualified: qualified,
      ),
    );
    unawaited(_engagementWrite);
  }

  void _load() {
    try {
      final data = jsonDecode(prefs.getString(storageKey) ?? '{}') as Map;
      for (final entry
          in ((data['legacy'] as Map?) ?? (data['days'] as Map?) ?? {})
              .entries) {
        final seconds = (entry.value as num?)?.toInt() ?? 0;
        if (seconds >= 0 && DateTime.tryParse(entry.key.toString()) != null) {
          _legacy[entry.key.toString()] = seconds;
        }
      }
      for (final raw in (data['events'] as List?) ?? []) {
        try {
          _events.add(
            StudyEvent.fromJson(Map<String, dynamic>.from(raw as Map)),
          );
        } catch (_) {
          /* Preserve other valid saved events. */
        }
      }
      _completed.addAll(((data['completed'] as List?) ?? []).cast<String>());
      _recompute();
      goalAlerts = data['goalAlerts'] == true;
      streakAlerts = data['streakAlerts'] == true;
      dailyGoal = ((data['dailyGoal'] as num?)?.toInt() ?? 120)
          .clamp(1, 1440)
          .toInt();
      weeklyGoal = ((data['weeklyGoal'] as num?)?.toInt() ?? 840)
          .clamp(1, 10080)
          .toInt();
      customGoal = ((data['customGoal'] as num?)?.toInt() ?? 90)
          .clamp(1, 10080)
          .toInt();
      for (final value in (data['tasks'] as List?) ?? []) {
        if (value is Map) {
          final task = StudyTask.fromJson(Map<String, dynamic>.from(value));
          if (task.title.isNotEmpty) _tasks.add(task);
        }
      }
    } catch (_) {
      unawaited(
        prefs.setString(
          '${storageKey}_recovery',
          prefs.getString(storageKey) ?? '',
        ),
      );
      saveError =
          'Saved data needs recovery. The original record has been retained.';
    }
  }

  void _save() {
    final encoded = jsonEncode({
      'version': 2,
      'legacy': _legacy,
      'events': _events.map((e) => e.toJson()).toList(),
      'completed': _completed.toList(),
      'dailyGoal': dailyGoal,
      'weeklyGoal': weeklyGoal,
      'customGoal': customGoal,
      'goalAlerts': goalAlerts,
      'streakAlerts': streakAlerts,
      'tasks': _tasks.map((t) => t.toJson()).toList(),
    });
    _writes = _writes
        .catchError((_) {})
        .then((_) async {
          if (!await prefs.setString(storageKey, encoded)) {
            throw StateError('Save failed');
          }
        })
        .catchError((Object e) {
          saveError =
              'Study progress could not be saved. Keep the app open and retry.';
          if (!_disposed) notifyListeners();
        });
  }

  int get todaySeconds => _days[studyDayKey(clock())] ?? 0;
  int get weekSeconds => StudyStats.weekSeconds(_days, clock());
  int get currentStreak => StudyStats.streak(_days, clock());
  int get highestStreak => StudyStats.bestStreak(_days, clock());
  List<String> get recentBreaks => StudyStats.recentBreaks(_days, clock());
  Map<String, int> get days => Map.unmodifiable(_days);
  List<StudyTask> get tasks =>
      List.unmodifiable(_tasks.where((t) => t.kind == 'task'));
  List<StudyTask> get reminders =>
      List.unmodifiable(_tasks.where((t) => t.kind == 'reminder'));
  int get completedTasks =>
      _tasks.where((t) => t.kind == 'task' && t.done).length;
  int get pendingCount =>
      _tasks.where((task) => task.kind == 'task' && !task.done).length;

  /// Do not leave an idle periodic timer alive in the app or widget tests.
  /// Only tick while studying or awaiting a due in-app reminder.
  void _manageTicker() {
    final needed =
        running ||
        _tasks.any(
          (t) =>
              t.enabled &&
              !t.done &&
              !t.alerted &&
              t.repeat == 'none' &&
              t.due != null,
        );
    if (needed && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!needed && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void _tick() {
    if (running) {
      final now = clock(), delta = _elapsedMs() - _lastMs;
      final wallDelta = now.difference(_lastTick!).inMilliseconds;
      if (delta < 0 ||
          delta > 30000 ||
          (wallDelta - delta).abs() > 2000 ||
          now.difference(_interaction ?? now) > const Duration(minutes: 5)) {
        running = false;
        _lastTick = null;
        _manageTicker();
        _save();
        notifyListeners();
      } else if (delta >= 1000) {
        final used = delta ~/ 1000 * 1000;
        final end = _lastTick!.add(Duration(milliseconds: used));
        _events.addAll(splitSession(_session!, _lastTick!, end));
        _lastTick = end;
        _lastMs += used;
        _recompute();
        refreshEngagementReminders();
        if (++_elapsedTicks % 5 == 0) _save();
        notifyListeners();
      }
    }
    _checkReminders();
  }

  void checkpoint() => _tick();
  StudySyncWorker? _sync;
  String get cloudStatus => _cloudStatus;
  String _cloudStatus = 'Saved on this device';
  void attachCloud(StudyCloud cloud) {
    _sync?.dispose();
    _sync = StudySyncWorker(
      cloud: cloud,
      events: () => pendingEvents,
      acknowledge: (ids) async {
        acknowledge(ids);
        await flush();
      },
      running: () => running,
      session: () => _session,
      onStatus: (status) {
        if (!_disposed && status != _cloudStatus) {
          _cloudStatus = status;
          notifyListeners();
        }
      },
    );
  }

  void start() {
    if (running) return;
    _session ??= studyId();
    running = true;
    _sync?.changed();
    _lastTick = clock();
    _lastMs = _elapsedMs();
    interaction();
    _manageTicker();
    _save();
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _tick();
    running = false;
    _sync?.changed();
    _lastTick = null;
    _manageTicker();
    _save();
    if (!_disposed) notifyListeners();
  }

  void stop() {
    pause();
    if (_session != null) _completed.add(_session!);
    _session = null;
    _sync?.changed();
    _save();
    notifyListeners();
  }

  void setGoals(int daily, int weekly) {
    dailyGoal = daily.clamp(1, 1440).toInt();
    weeklyGoal = weekly.clamp(1, 10080).toInt();
    refreshEngagementReminders();
    _save();
    notifyListeners();
  }

  void setCustomGoal(int value) {
    customGoal = value.clamp(1, 10080).toInt();
    _save();
    notifyListeners();
  }

  void addTask(String title, DateTime? due) {
    if (title.trim().isEmpty) return;
    final task = StudyTask(
      DateTime.now().microsecondsSinceEpoch.toString(),
      title.trim(),
      due: due,
    );
    _tasks.insert(0, task);
    if (due != null) unawaited(_scheduleDevice(task));
    _save();
    notifyListeners();
    _checkReminders();
    _manageTicker();
  }

  void toggleTask(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tasks[i] = _tasks[i].change(done: !_tasks[i].done);
    if (_tasks[i].done) {
      if (scheduleDevice) {
        unawaited(
          StudyNotificationScheduler.instance.cancel('$storageKey:$id'),
        );
      }
    } else {
      unawaited(_scheduleDevice(_tasks[i]));
    }
    _manageTicker();
    _save();
    notifyListeners();
  }

  void deleteTask(String id) {
    if (scheduleDevice) {
      unawaited(StudyNotificationScheduler.instance.cancel('$storageKey:$id'));
    }
    _tasks.removeWhere((t) => t.id == id);
    _manageTicker();
    _save();
    notifyListeners();
  }

  Future<void> _scheduleDevice(StudyTask task) async {
    if (!scheduleDevice) return;
    if (!task.enabled || task.done || task.due == null) {
      await StudyNotificationScheduler.instance.cancel(
        '$storageKey:${task.id}',
      );
      return;
    }
    await StudyNotificationScheduler.instance.schedule(
      key: '$storageKey:${task.id}',
      title: task.title,
      due: task.due!,
      repeat: task.repeat,
      leadMinutes: task.leadMinutes,
      weekdays: task.weekdays,
      extraAlerts: task.extraAlerts,
      quiet: task.quiet,
      until: task.until,
      route: '/study-goals',
    );
  }

  Future<void> saveTask(StudyTask task) async {
    final i = _tasks.indexWhere((t) => t.id == task.id);
    if (i < 0) {
      _tasks.insert(0, task);
    } else {
      _tasks[i] = task;
    }
    _save();
    _manageTicker();
    notifyListeners();
    await _scheduleDevice(task);
  }

  void addDetailedTask(
    String title, {
    String category = 'General',
    String priority = 'medium',
    int estimatedMinutes = 30,
    DateTime? due,
  }) {
    if (title.trim().isEmpty) return;
    final task = StudyTask(
      DateTime.now().microsecondsSinceEpoch.toString(),
      title.trim(),
      due: due,
      category: category,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
    );
    _tasks.insert(0, task);
    if (due != null) unawaited(_scheduleDevice(task));
    _save();
    notifyListeners();
    _manageTicker();
  }

  void addReminder(
    String title,
    DateTime due, {
    String type = 'Study',
    String repeat = 'none',
    int leadMinutes = 0,
  }) {
    if (title.trim().isEmpty) return;
    final reminder = StudyTask(
      DateTime.now().microsecondsSinceEpoch.toString(),
      title.trim(),
      due: due,
      kind: 'reminder',
      category: type,
      repeat: repeat,
      leadMinutes: leadMinutes,
    );
    _tasks.insert(0, reminder);
    unawaited(_scheduleDevice(reminder));
    _save();
    notifyListeners();
    _manageTicker();
  }

  void toggleReminder(String id) {
    final index = _tasks.indexWhere((t) => t.id == id && t.kind == 'reminder');
    if (index < 0) return;
    final updated = _tasks[index].change(enabled: !_tasks[index].enabled);
    _tasks[index] = updated;
    if (updated.enabled) {
      unawaited(_scheduleDevice(updated));
    } else {
      if (scheduleDevice) {
        unawaited(
          StudyNotificationScheduler.instance.cancel('$storageKey:$id'),
        );
      }
    }
    _save();
    notifyListeners();
    _manageTicker();
  }

  void _checkReminders() {
    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (!task.done &&
          task.enabled &&
          !task.alerted &&
          task.repeat == 'none' &&
          task.due != null &&
          !task.due!.isAfter(now)) {
        _tasks[i] = task.change(alerted: true);
        changed = true;
        onReminder(task);
      }
    }
    if (changed) {
      _manageTicker();
      _save();
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
    if (state == AppLifecycleState.resumed) {
      _checkReminders();
      refreshEngagementReminders(force: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sync?.dispose();
    pause();
    _watch.stop();
    _timer?.cancel();
    // Account-scoped alarms must not survive a logout/account switch.
    if (scheduleDevice) {
      unawaited(
        StudyNotificationScheduler.instance.cancel('$storageKey:engagement'),
      );
      for (final task in _tasks) {
        unawaited(
          StudyNotificationScheduler.instance.cancel('$storageKey:${task.id}'),
        );
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final studyTrackerProvider = ChangeNotifierProvider<StudyTracker>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final uid = user?.uid ?? 'guest';
  final tracker = StudyTracker(
    ref.read(sharedPrefsProvider),
    'hyzen_study_v1_$uid',
    (task) {
      ref
          .read(notificationsProvider.notifier)
          .addLocalReminder('Study reminder', task.title, task.id);
    },
  );
  if (user != null &&
      studyApiBase.isNotEmpty &&
      ref.watch(firebaseReadyProvider)) {
    tracker.attachCloud(StudyCloud(user));
  }
  return tracker;
});

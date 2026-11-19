import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';
import '../../core/widgets/surfaces.dart';
import 'study_cloud.dart';
import 'study_tracker.dart';
import 'study_notifications.dart';

String calendarDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PlannerEvent {
  const PlannerEvent({
    required this.id,
    required this.title,
    required this.at,
    required this.color,
    this.kind = 'Test',
    this.leadMinutes = 30,
  });
  final String id, title, kind;
  final DateTime at;
  final int color, leadMinutes;
  String get day => calendarDay(at);
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'day': day,
    'at': at.toUtc().toIso8601String(),
    'color': color,
    'kind': kind,
    'leadMinutes': leadMinutes,
  };
  factory PlannerEvent.fromJson(Map<String, dynamic> j) => PlannerEvent(
    id: j['id'],
    title: j['title'],
    at: DateTime.parse(j['at']).toLocal(),
    color: j['color'],
    kind: j['kind'] ?? 'Test',
    leadMinutes: j['leadMinutes'] ?? 30,
  );
}

class CalendarController extends ChangeNotifier with WidgetsBindingObserver {
  CalendarController(this.prefs, this.key, this.cloud, this.onEvent) {
    try {
      final raw = jsonDecode(prefs.getString(key) ?? '{}') as Map;
      for (final e in raw['events'] ?? []) {
        final event = PlannerEvent.fromJson(Map<String, dynamic>.from(e));
        _events[event.id] = event;
      }
      _pending.addAll(Map<String, dynamic>.from(raw['pending'] ?? {}));
    } catch (_) {
      error = 'Could not read saved calendar. Original data retained.';
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(sync());
    if (cloud?.supportsRealtime == true) {
      _subscription = cloud!
          .watch('calendar')
          .listen(
            (data) {
              if (busy) {
                _pendingRemote = data;
                return;
              }
              _queueRemote(data);
            },
            onError: (Object _) {
              if (!_dead) {
                error = 'Calendar sync unavailable · local changes are safe';
                notifyListeners();
              }
            },
          );
    }
    if (cloud != null) {
      _timer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (_foreground &&
            (cloud?.supportsRealtime != true || _pending.isNotEmpty)) {
          unawaited(sync());
        }
      });
    }
  }
  final SharedPreferences prefs;
  final String key;
  final StudyCloud? cloud;
  final Future<void> Function(PlannerEvent?, String) onEvent;
  final Map<String, PlannerEvent> _events = {};
  final Map<String, dynamic> _pending = {};
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Map<String, dynamic>? _pendingRemote;
  Future<void> _remoteWrites = Future.value();
  bool busy = false, _dead = false, _foreground = true;
  String? error;
  List<PlannerEvent> get events =>
      _events.values.toList()..sort((a, b) => a.at.compareTo(b.at));
  List<PlannerEvent> onDay(DateTime d) =>
      events.where((e) => e.day == calendarDay(d)).toList();
  Future<void> _save() async {
    await prefs.setString(
      key,
      jsonEncode({
        'events': _events.values.map((e) => e.toJson()).toList(),
        'pending': _pending,
      }),
    );
  }

  Future<void> put(PlannerEvent event) async {
    _events[event.id] = event;
    _pending[event.id] = {'action': 'save', 'event': event.toJson()};
    await _save();
    await onEvent(event, event.id);
    if (!_dead) notifyListeners();
    unawaited(sync());
  }

  Future<void> remove(String id) async {
    _events.remove(id);
    _pending[id] = {'action': 'delete', 'id': id};
    await _save();
    await onEvent(null, id);
    if (!_dead) notifyListeners();
    unawaited(sync());
  }

  Future<void> sync() async {
    if (_dead || busy || cloud == null || !_foreground) return;
    busy = true;
    try {
      while (_pending.isNotEmpty && !_dead) {
        final id = _pending.keys.first,
            request = Map<String, dynamic>.from(_pending[_pending.keys.first]);
        final encoded = jsonEncode(request);
        await cloud!.call('calendarEvents', request);
        if (jsonEncode(_pending[id]) == encoded) _pending.remove(id);
        await _save();
      }
      final result = await cloud!.call('calendarEvents', {'action': 'read'});
      if (_dead) return;
      await _mergeRemote(result);
    } catch (_) {
      error = 'Offline · calendar saved on this device';
    } finally {
      busy = false;
      if (_pendingRemote != null && !_dead) {
        final remote = _pendingRemote!;
        _pendingRemote = null;
        _queueRemote(remote);
      }
      if (!_dead) notifyListeners();
    }
  }

  Future<void> _mergeRemote(Map<String, dynamic> result) async {
    if (_dead) return;
    final server = {
      for (final e in (result['events'] as List? ?? []))
        e['id'] as String: PlannerEvent.fromJson(Map<String, dynamic>.from(e)),
    };
    for (final id in _pending.keys) {
      if (_events.containsKey(id)) {
        server[id] = _events[id]!;
      } else {
        server.remove(id);
      }
    }
    for (final id
        in _events.keys.where((id) => !server.containsKey(id)).toList()) {
      await onEvent(null, id);
    }
    for (final e in server.values) {
      if (jsonEncode(_events[e.id]?.toJson()) != jsonEncode(e.toJson())) {
        await onEvent(e, e.id);
      }
    }
    _events
      ..clear()
      ..addAll(server);
    await _save();
    error = null;
    if (!_dead) notifyListeners();
  }

  void _queueRemote(Map<String, dynamic> data) {
    _remoteWrites = _remoteWrites.then((_) => _mergeRemote(data)).catchError((
      Object _,
    ) {
      if (!_dead) {
        error = 'Calendar sync unavailable · local changes are safe';
        notifyListeners();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(sync());
  }

  @override
  void dispose() {
    _dead = true;
    _timer?.cancel();
    _subscription?.cancel();
    cloud?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final calendarProvider = ChangeNotifierProvider<CalendarController>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final tracker = ref.read(studyTrackerProvider);
  return CalendarController(
    ref.read(sharedPrefsProvider),
    'hyzen_calendar_${user?.uid ?? 'guest'}',
    user != null && ref.watch(firebaseReadyProvider) && studyApiBase.isNotEmpty
        ? StudyCloud(user)
        : null,
    (event, id) async {
      final taskId = 'calendar_$id';
      if (event == null) {
        tracker.deleteTask(taskId);
        return;
      }
      await tracker.saveTask(
        StudyTask(
          taskId,
          '${event.kind}: ${event.title}',
          due: event.at,
          kind: 'reminder',
          category: 'Calendar',
          leadMinutes: event.leadMinutes,
          quiet: false,
        ),
      );
    },
  );
});

class StudyCalendarScreen extends ConsumerStatefulWidget {
  const StudyCalendarScreen({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  ConsumerState<StudyCalendarScreen> createState() =>
      _StudyCalendarScreenState();
}

class _StudyCalendarScreenState extends ConsumerState<StudyCalendarScreen> {
  late DateTime selected = widget.initialDate ?? DateTime.now();
  Future<void> edit([PlannerEvent? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    var kind = existing?.kind ?? 'Test', color = existing?.color ?? 0xffd46a61;
    var time = TimeOfDay.fromDateTime(
      existing?.at ?? DateTime(selected.year, selected.month, selected.day, 9),
    );
    var lead = existing?.leadMinutes ?? 30;
    final result = await showDialog<PlannerEvent>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(
            existing == null
                ? 'Plan ${selected.day}/${selected.month}'
                : 'Edit event',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: title,
                  maxLength: 120,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'What’s happening?',
                    hintText: 'Pharmacology paper',
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final item in ['Test', 'Exam', 'Event'])
                      ChoiceChip(
                        label: Text(item),
                        selected: kind == item,
                        onSelected: (_) => set(() => kind = item),
                      ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: c,
                      initialTime: time,
                    );
                    if (picked != null && c.mounted) set(() => time = picked);
                  },
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(time.format(c)),
                ),
                DropdownButtonFormField<int>(
                  initialValue: lead,
                  decoration: const InputDecoration(labelText: 'Remind me'),
                  items: [
                    for (final m in [0, 10, 30, 60, 1440])
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          m == 0
                              ? 'At event time'
                              : m == 1440
                              ? '1 day before'
                              : '$m minutes before',
                        ),
                      ),
                  ],
                  onChanged: (v) => set(() => lead = v ?? 30),
                ),
                const SizedBox(height: 12),
                const Text('Event color'),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final v in [
                      0xffd46a61,
                      0xff568a73,
                      0xff668bc4,
                      0xff9574b8,
                      0xffc38b3f,
                    ])
                      IconButton(
                        tooltip: 'Choose ${v.toRadixString(16)}',
                        onPressed: () => set(() => color = v),
                        icon: Icon(
                          color == v ? Icons.check_circle : Icons.circle,
                          color: Color(v),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(
                  c,
                  PlannerEvent(
                    id:
                        existing?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    title: title.text.trim(),
                    at: DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                      time.hour,
                      time.minute,
                    ),
                    color: color,
                    kind: kind,
                    leadMinutes: lead,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    if (result == null || !mounted) return;
    final allowed = await StudyNotificationScheduler.instance
        .requestPermission();
    await ref.read(calendarProvider).put(result);
    if (!mounted) return;
    final error = StudyNotificationScheduler.instance.lastError;
    if (!allowed || error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !allowed
                ? 'Event saved. Enable phone notifications for reminders.'
                : error!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = ref.watch(calendarProvider),
        items = planner.onDay(selected);
    return HBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Study calendar'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text(
              'Make room for what matters.',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text('Tests, papers and plans, together in one place.'),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .8),
                borderRadius: BorderRadius.circular(24),
              ),
              child: CalendarDatePicker(
                initialDate: selected,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                onDateChanged: (d) => setState(() => selected = d),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selected.day}/${selected.month}/${selected.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => edit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add event'),
                ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nothing planned yet. Add a test, exam or reminder.',
                ),
              ),
            for (final e in items)
              Card(
                color: Color(e.color).withValues(alpha: .13),
                child: ListTile(
                  onTap: () => edit(e),
                  leading: Icon(
                    e.kind == 'Exam'
                        ? Icons.school_outlined
                        : Icons.event_note_rounded,
                    color: Color(e.color),
                  ),
                  title: Text(
                    e.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${e.kind} · ${TimeOfDay.fromDateTime(e.at).format(context)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete event',
                    onPressed: () => ref.read(calendarProvider).remove(e.id),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              ),
            if (planner.error != null) Text(planner.error!),
          ],
        ),
      ),
    );
  }
}

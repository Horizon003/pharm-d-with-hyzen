/// Pure local-calendar planner; OS repeating alarms carry the weekly cadence.
class PlannedReminder {
  const PlannedReminder(this.time, {this.weekly = false});
  final DateTime time;
  final bool weekly;
}

List<PlannedReminder> reminderPlan({
  required DateTime now,
  required DateTime due,
  String repeat = 'none',
  List<int> weekdays = const [],
  int leadMinutes = 0,
  int extraAlerts = 0,
  bool quiet = true,
  DateTime? until,
}) {
  final results = <PlannedReminder>[];
  final allowed = switch (repeat) {
    'daily' => {1, 2, 3, 4, 5, 6, 7},
    'weekdays' => {1, 2, 3, 4, 5},
    'weekly' => {due.weekday},
    'custom' => weekdays.where((d) => d >= 1 && d <= 7).toSet(),
    _ => <int>{},
  };
  void add(DateTime occurrence, bool weekly) {
    for (var extra = 0; extra <= extraAlerts.clamp(0, 2); extra++) {
      var at = occurrence
          .subtract(Duration(minutes: leadMinutes.clamp(0, 120)))
          .add(Duration(minutes: extra * 15));
      if (weekly && !at.isAfter(now)) {
        at = DateTime(at.year, at.month, at.day + 7, at.hour, at.minute);
      }
      if (!at.isAfter(now) || (quiet && (at.hour >= 22 || at.hour < 7))) {
        continue;
      }
      if (until != null &&
          at.isAfter(DateTime(until.year, until.month, until.day, 23, 59))) {
        continue;
      }
      results.add(PlannedReminder(at, weekly: weekly));
    }
  }

  if (repeat == 'none') {
    add(due, false);
    return results;
  }
  if (allowed.isEmpty) return results;
  final start = due.isAfter(now) ? due : now;
  final emitted = <int>{};
  // Finite recurrences are one-shot alarms, bounded to 30 days / 93 alerts.
  for (var offset = 0; offset <= (until == null ? 14 : 30); offset++) {
    final day = DateTime(
      start.year,
      start.month,
      start.day + offset,
      due.hour,
      due.minute,
    );
    if (day.isBefore(due) || !allowed.contains(day.weekday)) continue;
    if (until == null && emitted.contains(day.weekday)) continue;
    if (until != null &&
        day.isAfter(DateTime(until.year, until.month, until.day, 23, 59))) {
      break;
    }
    final before = results.length;
    add(day, until == null);
    if (results.length > before) emitted.add(day.weekday);
  }
  results.sort((a, b) => a.time.compareTo(b.time));
  return results;
}

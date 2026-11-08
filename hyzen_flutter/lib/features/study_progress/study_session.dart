import 'dart:math';

String studyId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StudyEvent {
  const StudyEvent(
    this.id,
    this.session,
    this.start,
    this.end,
    this.day, {
    this.synced = false,
  });
  final String id, session, day;
  final DateTime start, end;
  final bool synced;
  Map<String, dynamic> toJson() => {
    'id': id,
    'session': session,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
    'day': day,
    'synced': synced,
  };
  factory StudyEvent.fromJson(Map<String, dynamic> j) => StudyEvent(
    j['id'],
    j['session'],
    DateTime.fromMillisecondsSinceEpoch(j['start']),
    DateTime.fromMillisecondsSinceEpoch(j['end']),
    j['day'],
    synced: j['synced'] == true,
  );
  StudyEvent acknowledge() =>
      StudyEvent(id, session, start, end, day, synced: true);
}

List<StudyEvent> splitSession(String id, DateTime start, DateTime end) {
  final events = <StudyEvent>[];
  var cursor = start;
  while (cursor.isBefore(end)) {
    final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
    final finish = midnight.isBefore(end) ? midnight : end;
    events.add(StudyEvent(studyId(), id, cursor, finish, dayKey(cursor)));
    cursor = finish;
  }
  return events;
}

Map<String, int> sessionTotals(Iterable<StudyEvent> events) {
  final groups = <String, List<StudyEvent>>{};
  for (final e in events) {
    if (e.end.isAfter(e.start)) groups.putIfAbsent(e.day, () => []).add(e);
  }
  return groups.map((day, list) {
    list.sort((a, b) => a.start.compareTo(b.start));
    var start = list.first.start, end = list.first.end, ms = 0;
    for (final e in list.skip(1)) {
      if (!e.start.isAfter(end)) {
        if (e.end.isAfter(end)) end = e.end;
      } else {
        ms += end.difference(start).inMilliseconds;
        start = e.start;
        end = e.end;
      }
    }
    return MapEntry(day, (ms + end.difference(start).inMilliseconds) ~/ 1000);
  });
}

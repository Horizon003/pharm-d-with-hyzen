class EngagementReminder {
  const EngagementReminder(this.time, this.message, this.route);
  final DateTime time;
  final String message, route;
}

/// One rolling week of goal nudges, and only the next known streak-risk day.
/// Future streaks are never assumed. Recomputed when progress or preferences change.
List<EngagementReminder> engagementReminders({
  required DateTime now,
  required bool goals,
  required bool streaks,
  required int todaySeconds,
  required int dailyGoalMinutes,
  required bool yesterdayQualified,
}) {
  final result = <EngagementReminder>[];
  if (goals) {
    for (var i = 0; i < 7; i++) {
      final time = DateTime(now.year, now.month, now.day + i, 18);
      if (time.isAfter(now) &&
          (i != 0 || todaySeconds < dailyGoalMinutes * 60)) {
        result.add(
          EngagementReminder(
            time,
            'Make some time for your daily study goal.',
            '/study-goals',
          ),
        );
      }
    }
  }
  if (streaks && (yesterdayQualified || todaySeconds >= 900)) {
    final offset = todaySeconds >= 900 ? 1 : 0;
    final time = DateTime(now.year, now.month, now.day + offset, 20);
    if (time.isAfter(now)) {
      result.add(
        EngagementReminder(
          time,
          'Keep your study streak going with 15 minutes of study.',
          '/study-streak',
        ),
      );
    }
  }
  return result;
}

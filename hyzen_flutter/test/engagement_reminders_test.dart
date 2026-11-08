import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/study_progress/engagement_reminders.dart';

void main() {
  test(
    'goal completion removes today but retains a rolling week of future nudges',
    () {
      final now = DateTime(2026, 11, 8, 10);
      final reminders = engagementReminders(
        now: now,
        goals: true,
        streaks: false,
        todaySeconds: 7200,
        dailyGoalMinutes: 120,
        yesterdayQualified: false,
      );
      expect(reminders.length, 6);
      expect(
        reminders.every((r) => r.time.day > 8 && r.time.hour == 18),
        isTrue,
      );
    },
  );
  test(
    'streak risk schedules only the next known day and never assumes future streaks',
    () {
      final now = DateTime(2026, 11, 8, 10);
      List<EngagementReminder> plan(int seconds, bool previous) =>
          engagementReminders(
            now: now,
            goals: false,
            streaks: true,
            todaySeconds: seconds,
            dailyGoalMinutes: 120,
            yesterdayQualified: previous,
          );
      expect(plan(0, false), isEmpty);
      expect(plan(0, true).single.time, DateTime(2026, 11, 8, 20));
      expect(plan(900, false).single.time, DateTime(2026, 11, 9, 20));
      expect(plan(900, true).length, 1);
    },
  );
  test('disabled and expired alerts do not appear', () {
    final now = DateTime(2026, 11, 8, 21);
    expect(
      engagementReminders(
        now: now,
        goals: false,
        streaks: false,
        todaySeconds: 0,
        dailyGoalMinutes: 120,
        yesterdayQualified: true,
      ),
      isEmpty,
    );
    expect(
      engagementReminders(
        now: now,
        goals: false,
        streaks: true,
        todaySeconds: 0,
        dailyGoalMinutes: 120,
        yesterdayQualified: true,
      ),
      isEmpty,
    );
  });
}

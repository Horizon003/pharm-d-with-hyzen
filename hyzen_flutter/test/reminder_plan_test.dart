import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/study_progress/reminder_plan.dart';
void main() {
  test('future recurrence never schedules before chosen start', () {
    final due = DateTime(2026,11,16,9);
    final plan = reminderPlan(now: DateTime(2026,11,7), due: due, repeat: 'custom', weekdays: [1,3]);
    expect(plan.length,2);
    expect(plan.every((p) => !p.time.isBefore(due) && p.weekly),isTrue);
    expect(plan.map((p) => p.time.weekday).toSet(), {1,3});
  });
  test('advance alert crosses midnight using prior weekday', () {
    final plan = reminderPlan(now: DateTime(2026,11,7), due: DateTime(2026,11,9,0,10), repeat:'weekly', leadMinutes:30, quiet:false);
    expect(plan.single.time,DateTime(2026,11,8,23,40));
    expect(plan.single.time.weekday,7);
  });
  test('quiet hours skip alarms and extras are bounded', () {
    expect(reminderPlan(now:DateTime(2026,11,7),due:DateTime(2026,11,7,23)),isEmpty);
    final plan=reminderPlan(now:DateTime(2026,11,7),due:DateTime(2026,11,7,9),extraAlerts:99);
    expect(plan.map((p)=>p.time.minute).toList(),[0,15,30]);
  });
  test('finite recurrences stop on selected date and do not repeat forever', () {
    final plan=reminderPlan(now:DateTime(2026,11,7),due:DateTime(2026,11,8,9),repeat:'daily',until:DateTime(2026,11,10),extraAlerts:2);
    expect(plan.length,9);
    expect(plan.every((p)=>!p.weekly),isTrue);
    expect(plan.last.time,DateTime(2026,11,10,9,30));
  });
  test('relaunch after first alert retains next weekly primary alert', () {
    final plan=reminderPlan(now:DateTime(2026,11,9,9,5),due:DateTime(2026,11,9,9),repeat:'weekly',extraAlerts:2);
    expect(plan.length,3);
    expect(plan.any((p)=>p.time == DateTime(2026,11,16,9)),isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/features/study_progress/study_tracker.dart';
import 'package:hyzen_pharmd/features/study_progress/study_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('midnight split and overlapping retry events do not double count', () {
    final events = splitSession(
      's',
      DateTime(2026, 11, 7, 23, 59, 50),
      DateTime(2026, 11, 8, 0, 0, 10),
    );
    expect(sessionTotals([...events, ...events]), {
      '2026-11-07': 10,
      '2026-11-08': 10,
    });
  });
  test(
    'explicit start, pause, resume, stop and restart preserve durable events',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 11, 7, 12), ms = 0;
      final t = StudyTracker(
        prefs,
        'test',
        (_) {},
        clock: () => now,
        elapsedMs: () => ms,
        scheduleDevice: false,
      );
      void advance(int seconds) {
        ms += seconds * 1000;
        now = now.add(Duration(seconds: seconds));
        t.checkpoint();
      }

      advance(10);
      expect(t.todaySeconds, 0);
      t.start();
      advance(10);
      t.pause();
      advance(10);
      expect(t.todaySeconds, 10);
      t.start();
      advance(5);
      t.stop();
      expect(t.todaySeconds, 15);
      expect(t.completedSessions.length, 1);
      await t.flush();
      t.dispose();
      final restored = StudyTracker(
        prefs,
        'test',
        (_) {},
        clock: () => now,
        scheduleDevice: false,
      );
      expect(restored.running, false);
      expect(restored.todaySeconds, 15);
      expect(restored.pendingEvents.length, 2);
      restored.acknowledge({restored.pendingEvents.first.id});
      await restored.flush();
      expect(restored.pendingEvents.length, 1);
      restored.dispose();
    },
  );
  test('wall clock jumps cannot inflate elapsed time', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime(2026, 11, 7, 12), ms = 0;
    final t = StudyTracker(
      prefs,
      'jump',
      (_) {},
      clock: () => now,
      elapsedMs: () => ms,
      scheduleDevice: false,
    );
    t.start();
    now = now.add(const Duration(hours: 2));
    ms = 1000;
    t.checkpoint();
    expect(t.todaySeconds, 0);
    expect(t.running, false);
    t.dispose();
    await t.flush();
  });
  test(
    'legacy totals migrate once and are never uploaded as verified events',
    () async {
      SharedPreferences.setMockInitialValues({
        'old': '{"days":{"2026-11-07":900},"dailyGoal":30}',
      });
      final prefs = await SharedPreferences.getInstance();
      final t = StudyTracker(
        prefs,
        'old',
        (_) {},
        clock: () => DateTime(2026, 11, 7),
        scheduleDevice: false,
      );
      expect(t.currentStreak, 1);
      expect(t.pendingEvents, isEmpty);
      t.setGoals(40, 240);
      await t.flush();
      t.dispose();
      final r = StudyTracker(
        prefs,
        'old',
        (_) {},
        clock: () => DateTime(2026, 11, 7),
        scheduleDevice: false,
      );
      expect(r.todaySeconds, 900);
      expect(r.dailyGoal, 40);
      r.dispose();
    },
  );
}

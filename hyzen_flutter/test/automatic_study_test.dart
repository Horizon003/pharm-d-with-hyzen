import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/features/study_progress/study_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'silent reading continues, closure gets 30s uncredited grace, reopening joins session',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 11, 18, 12), ms = 0;
      final t = StudyTracker(
        prefs,
        'automatic',
        (_) {},
        clock: () => now,
        elapsedMs: () => ms,
        scheduleDevice: false,
      );
      void advance(int seconds) {
        for (var i = 0; i < seconds; i++) {
          now = now.add(const Duration(seconds: 1));
          ms += 1000;
          t.checkpoint();
        }
      }

      final first = Object(), second = Object();
      t.documentOpened(first);
      advance(360);
      expect(t.running, true);
      expect(t.todaySeconds, 360);
      t.documentClosed(first);
      expect(t.running, false);
      expect(t.awaitingClose, true);
      advance(29);
      expect(t.hasSession, true);
      expect(t.todaySeconds, 360);
      t.documentOpened(second);
      expect(t.running, true);
      expect(t.completedSessions, isEmpty);
      advance(10);
      t.documentClosed(second);
      advance(30);
      expect(t.hasSession, false);
      expect(t.todaySeconds, 370);
      expect(t.completedSessions.length, 1);
      t.dispose();
      await t.flush();
    },
  );
  testWidgets(
    'foreground file resumes after background; overlapping owners do not double count',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2026, 11, 18, 12), ms = 0;
      final t = StudyTracker(
        prefs,
        'owners',
        (_) {},
        clock: () => now,
        elapsedMs: () => ms,
        scheduleDevice: false,
      );
      final a = Object(), b = Object();
      t.documentOpened(a);
      t.documentOpened(b);
      now = now.add(const Duration(seconds: 10));
      ms += 10000;
      t.checkpoint();
      expect(t.todaySeconds, 10);
      t.documentClosed(a);
      expect(t.running, true);
      t.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(hours: 1));
      ms += 3600000;
      t.checkpoint();
      expect(t.todaySeconds, 10);
      t.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(t.running, true);
      now = now.add(const Duration(seconds: 10));
      ms += 10000;
      t.checkpoint();
      expect(t.todaySeconds, 20);
      t.documentClosed(b);
      t.dispose();
      await t.flush();
    },
  );
}

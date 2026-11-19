import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/features/study_progress/reward_controller.dart';
import 'package:hyzen_pharmd/features/study_progress/study_calendar.dart';
import 'package:hyzen_pharmd/features/study_progress/study_cloud.dart';

class _User extends Fake implements User {}

class _LostResponseCloud extends StudyCloud {
  @override
  bool get supportsRealtime => false;
  _LostResponseCloud() : super(_User());
  bool fail = true;
  int balance = 0;
  final claimed = <String>{};
  String get today => DateTime.now()
      .toUtc()
      .add(const Duration(hours: 5))
      .toIso8601String()
      .substring(0, 10);
  Map<String, dynamic> get snapshot => {
    'today': today,
    'points': balance,
    'streak': claimed.length,
    'bestStreak': claimed.length,
    'claimedDays': claimed.toList(),
    'claimedMilestones': <int>[],
  };
  @override
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> data,
  ) async {
    if (method == 'claimReward') {
      if (claimed.add(data['day'])) balance += 100;
      if (fail) throw StateError('Response lost');
    }
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'lost claim response is retried once logically and never grants an extra reward',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cloud = _LostResponseCloud();
      final r = RewardController(prefs, 'wallet', cloud);
      await tester.pump();
      expect(await r.claim(), false);
      expect(cloud.balance, 100);
      expect(prefs.getString('wallet_pending'), isNotNull);
      cloud.fail = false;
      await r.refresh();
      expect(r.points, 100);
      expect(r.claimedToday, true);
      expect(prefs.getString('wallet_pending'), isNull);
      r.dispose();
      final restored = RewardController(prefs, 'wallet', null);
      expect(restored.points, 100);
      expect(restored.claimedToday, true);
      restored.dispose();
    },
  );
  testWidgets(
    'calendar edits persist offline, retain color, reminders, and account isolation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final alarms = <String>[];
      final c = CalendarController(prefs, 'calendar_a', null, (e, id) async {
        alarms.add(e == null ? 'delete:$id' : 'save:$id');
      });
      final event = PlannerEvent(
        id: 'exam',
        title: 'Pharmacology',
        at: DateTime(2026, 11, 23, 9),
        color: 0xffd46a61,
        kind: 'Exam',
      );
      await c.put(event);
      expect(c.onDay(DateTime(2026, 11, 23)).single.color, 0xffd46a61);
      c.dispose();
      final restored = CalendarController(
        prefs,
        'calendar_a',
        null,
        (e, id) async {},
      );
      expect(restored.events.single.title, 'Pharmacology');
      final other = CalendarController(
        prefs,
        'calendar_b',
        null,
        (e, id) async {},
      );
      expect(other.events, isEmpty);
      await restored.remove('exam');
      expect(restored.events, isEmpty);
      restored.dispose();
      other.dispose();
      expect(alarms, ['save:exam']);
    },
  );
}

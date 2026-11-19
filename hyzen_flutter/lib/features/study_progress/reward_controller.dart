import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';
import 'study_cloud.dart';

const rewardMilestones = [5, 7, 14, 30, 60, 100];
final rankRefreshProvider = StateProvider<int>((ref) => 0);

class RewardController extends ChangeNotifier with WidgetsBindingObserver {
  RewardController(this.prefs, this.key, this.cloud) {
    try {
      data = Map<String, dynamic>.from(
        jsonDecode(prefs.getString(key) ?? '{}'),
      );
    } catch (_) {
      /* Keep confirmed server data only. */
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    if (cloud?.supportsRealtime == true) {
      _subscription = cloud!
          .watch('rewards')
          .listen(
            apply,
            onError: (Object error) {
              if (!_dead) {
                this.error = 'Sync unavailable · showing confirmed points';
                notifyListeners();
              }
            },
          );
    }
    if (cloud != null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_foreground &&
            (cloud?.supportsRealtime != true ||
                today != _dayInPakistan() ||
                prefs.containsKey('${key}_pending'))) {
          unawaited(refresh());
        }
      });
    }
  }
  final SharedPreferences prefs;
  final String key;
  final StudyCloud? cloud;
  Map<String, dynamic> data = {};
  bool busy = false, _dead = false, _foreground = true;
  String? error;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  int get points => (data['points'] as num?)?.toInt() ?? 0;
  int get streak => (data['streak'] as num?)?.toInt() ?? 0;
  int get best => (data['bestStreak'] as num?)?.toInt() ?? 0;
  String get today => data['today'] as String? ?? _dayInPakistan();
  List<String> get days =>
      (data['claimedDays'] as List? ?? []).whereType<String>().toList();
  List<int> get badges => (data['claimedMilestones'] as List? ?? [])
      .whereType<num>()
      .map((e) => e.toInt())
      .toList();
  bool get claimedToday => days.contains(_dayInPakistan());
  bool get connected => cloud != null;
  static String _dayInPakistan() => DateTime.now()
      .toUtc()
      .add(const Duration(hours: 5))
      .toIso8601String()
      .substring(0, 10);
  void apply(Map<String, dynamic> value) {
    if (_dead) return;
    if ((value['updatedAt'] as num? ?? 0) < (data['updatedAt'] as num? ?? 0)) {
      return;
    }
    data = value;
    unawaited(prefs.setString(key, jsonEncode(value)));
    error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_dead || busy || cloud == null || !_foreground) return;
    busy = true;
    try {
      apply(await cloud!.call('rewardState', {}));
      final pending = prefs.getString('${key}_pending');
      if (pending != null) {
        final request = Map<String, dynamic>.from(jsonDecode(pending));
        if (request['day'] != today) {
          await prefs.remove('${key}_pending');
          error =
              'Yesterday’s pending claim expired. Claim today while online.';
        } else {
          apply(await cloud!.call('claimReward', request));
          await prefs.remove('${key}_pending');
        }
      }
    } catch (_) {
      error = 'Offline · showing last confirmed points';
    } finally {
      busy = false;
      if (!_dead) notifyListeners();
    }
  }

  Future<bool> claim({int? milestone}) async {
    if (_dead || busy) return false;
    if (cloud == null) {
      error = 'Sign in to claim and sync your points.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    final request = <String, dynamic>{
      'kind': milestone == null ? 'daily' : 'achievement',
      'day': _dayInPakistan(),
      if (milestone != null) 'milestone': milestone,
    };
    try {
      // Persist before sending so a lost response retries the same immutable day.
      await prefs.setString('${key}_pending', jsonEncode(request));
      apply(await cloud!.call('claimReward', request));
      await prefs.remove('${key}_pending');
      return true;
    } catch (_) {
      error = 'Claim pending · reconnect to confirm your points';
      return false;
    } finally {
      busy = false;
      if (!_dead) notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(refresh());
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

final rewardProvider = ChangeNotifierProvider<RewardController>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return RewardController(
    ref.read(sharedPrefsProvider),
    'hyzen_rewards_${user?.uid ?? 'guest'}',
    user != null && ref.watch(firebaseReadyProvider) && studyApiBase.isNotEmpty
        ? StudyCloud(user)
        : null,
  );
});

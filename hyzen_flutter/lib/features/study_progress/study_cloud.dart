import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_study_store.dart';
import 'study_session.dart';

/// Study, rewards, calendar and ranking use the app's existing Firebase project.
/// PUSH_API_BASE belongs only to the independent OneSignal sender.
const studyApiBase = 'firestore://pharmawhisper-debd2';

class StudyCloud {
  StudyCloud(this.user, {FirebaseFirestore? firestore}) : _database = firestore;
  final User user;
  final FirebaseFirestore? _database;
  late final FirebaseStudyStore _store = FirebaseStudyStore(
    _database ?? FirebaseFirestore.instance,
    user.uid,
  );
  bool get supportsRealtime => true;
  Stream<Map<String, dynamic>> watch(String topic) => _store.watch(topic);
  Future<Map<String, dynamic>> call(String method, Map<String, dynamic> data) =>
      _store.call(method, data).timeout(const Duration(seconds: 20));
  void dispose() {}
}

/// Durable events remain in the tracker until explicitly acknowledged. A lost
/// response safely retries the same IDs. Reminder text and PDFs are never sent.
class StudySyncWorker {
  StudySyncWorker({
    required this.cloud,
    required this.events,
    required this.acknowledge,
    required this.running,
    required this.session,
    required this.onStatus,
    this.onRewards,
    this.onRank,
  }) {
    _schedule(Duration.zero);
  }
  final void Function(Map<String, dynamic>)? onRewards;
  final void Function()? onRank;
  final StudyCloud cloud;
  final List<StudyEvent> Function() events;
  final Future<void> Function(Set<String>) acknowledge;
  final bool Function() running;
  final String? Function() session;
  final void Function(String) onStatus;
  Timer? _timer;
  bool _disposed = false, _busy = false, _dirty = false, _rankPaused = false;
  int _failures = 0;
  String? _lease, _rewardLease;
  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_disposed) _timer = Timer(delay, _run);
  }

  void changed() {
    _dirty = true;
    if (!_busy) _schedule(const Duration(seconds: 1));
  }

  Future<void> _run() async {
    _timer = null;
    if (_disposed || _busy) return;
    _busy = true;
    _dirty = false;
    var failed = false;
    try {
      final batch = events().take(100).toList();
      if (batch.isNotEmpty) {
        final result = await cloud.call('syncStudy', {
          'events': batch.map((e) => e.toJson()).toList(),
        });
        final sent = batch.map((e) => e.id).toSet();
        final accepted = (result['accepted'] as List? ?? [])
            .whereType<String>()
            .where(sent.contains)
            .toSet();
        if (!_disposed) await acknowledge(accepted);
        if (accepted.isEmpty) throw StateError('No events acknowledged.');
      }
      if (!_disposed) {
        onStatus(
          events().isEmpty
              ? 'Personal study history synced'
              : 'Syncing saved study history',
        );
      }
      _failures = 0;
    } catch (_) {
      failed = true;
      _failures = (_failures + 1).clamp(1, 6);
      if (!_disposed) onStatus('Offline · study history safely queued');
    }
    if (!_disposed) {
      try {
        final current = session();
        if (running() && current != null) {
          final reward = await cloud.call('rewardPulse', {
            'session': current,
            'action': _rewardLease == current ? 'heartbeat' : 'start',
          });
          _rewardLease = current;
          if (!_disposed) onRewards?.call(reward);
        } else if (_rewardLease != null) {
          final reward = await cloud.call('rewardPulse', {
            'session': _rewardLease,
            'action': current == null ? 'stop' : 'pause',
          });
          _rewardLease = null;
          if (!_disposed) onRewards?.call(reward);
        }
      } catch (_) {
        _rewardLease = null;
      }
      try {
        final current = session();
        if (running() && current != null) {
          await cloud.call('studyPulse', {
            'session': current,
            'action': _lease == current && !_rankPaused ? 'heartbeat' : 'start',
          });
          _lease = current;
          _rankPaused = false;
          if (!_disposed) onRank?.call();
        } else if (_lease != null && (!_rankPaused || current == null)) {
          await cloud.call('studyPulse', {
            'session': _lease,
            'action': current == null ? 'stop' : 'pause',
          });
          if (current == null) {
            _lease = null;
          } else {
            _rankPaused = true;
          }
          if (!_disposed) onRank?.call();
        }
      } catch (_) {
        _lease = null; /* Unverified time never becomes rank points. */
      }
    }
    _busy = false;
    _schedule(
      Duration(
        seconds: _dirty
            ? 0
            : failed
            ? (5 * (1 << _failures)).clamp(10, 300)
            : running()
            ? 15
            : events().isNotEmpty
            ? 1
            : 60,
      ),
    );
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    cloud.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'study_session.dart';
import '../notifications/push_api.dart';

/// Set only after deploying and validating the authenticated callable backend.
const studyApiBase = String.fromEnvironment(
  'STUDY_API_BASE',
  defaultValue: pushApiBase,
);

class StudyCloud {
  StudyCloud(this.user, {http.Client? client})
    : client = client ?? http.Client();
  final User user;
  final http.Client client;
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> data,
  ) async {
    if (studyApiBase.isEmpty) {
      throw StateError('Study cloud is not configured.');
    }
    final token = await user.getIdToken();
    final response = await client
        .post(
          Uri.parse('$studyApiBase/$method'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Study cloud unavailable (${response.statusCode}).');
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (result['error'] != null) {
      throw StateError('Study cloud rejected this request.');
    }
    return Map<String, dynamic>.from(result['result'] ?? result['data']);
  }

  void dispose() => client.close();
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
  }) {
    _schedule(Duration.zero);
  }
  final StudyCloud cloud;
  final List<StudyEvent> Function() events;
  final Future<void> Function(Set<String>) acknowledge;
  final bool Function() running;
  final String? Function() session;
  final void Function(String) onStatus;
  Timer? _timer;
  bool _disposed = false, _busy = false;
  int _failures = 0;
  String? _lease;
  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_disposed) _timer = Timer(delay, _run);
  }

  void changed() {
    if (!_busy) _schedule(const Duration(seconds: 1));
  }

  Future<void> _run() async {
    _timer = null;
    if (_disposed || _busy) return;
    _busy = true;
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
          await cloud.call('studyPulse', {
            'session': current,
            'action': _lease == current ? 'heartbeat' : 'start',
          });
          _lease = current;
        } else if (_lease != null) {
          await cloud.call('studyPulse', {
            'session': _lease,
            'action': current == null ? 'stop' : 'pause',
          });
          _lease = null;
        }
      } catch (_) {
        _lease = null; /* Unverified time never becomes rank points. */
      }
    }
    _busy = false;
    _schedule(
      Duration(
        seconds: failed
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

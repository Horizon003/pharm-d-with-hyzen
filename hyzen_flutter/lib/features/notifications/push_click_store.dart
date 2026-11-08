import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Only an ID is retained. The authenticated server must authorize its contents
/// and destination before the click can affect an account's inbox or navigation.
class PushClickStore {
  PushClickStore(this.prefs, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final SharedPreferences prefs;
  final DateTime Function() clock;
  String key(String uid) => 'hyzen_pending_push_click_$uid';
  Future<void> remember(String uid, String id) async {
    await prefs.setString(
      key(uid),
      jsonEncode({'id': id, 'at': clock().millisecondsSinceEpoch}),
    );
  }

  String? pending(String uid) {
    try {
      final data = jsonDecode(prefs.getString(key(uid)) ?? '{}') as Map;
      final age = clock().millisecondsSinceEpoch - (data['at'] as num).toInt();
      final id = data['id'] as String;
      if (age < 0 ||
          age > const Duration(hours: 24).inMilliseconds ||
          !id.startsWith('push_')) {
        return null;
      }
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<void> forget(String uid, String id) async {
    if (pending(uid) == id) await prefs.remove(key(uid));
  }
}

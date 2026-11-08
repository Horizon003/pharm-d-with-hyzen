import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/features/notifications/push_click_store.dart';

void main() {
  test(
    'offline cold-start click survives restart and remains account-scoped',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 11, 8, 12);
      await PushClickStore(
        prefs,
        clock: () => now,
      ).remember('alice', 'push_message');
      final restored = PushClickStore(prefs, clock: () => now);
      expect(restored.pending('alice'), 'push_message');
      expect(restored.pending('bob'), isNull);
      expect(
        PushClickStore(
          prefs,
          clock: () => now.add(const Duration(hours: 25)),
        ).pending('alice'),
        isNull,
      );
    },
  );
  test('a late acknowledgement cannot erase a newer click', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PushClickStore(await SharedPreferences.getInstance());
    await store.remember('', 'push_first');
    await store.remember('', 'push_second');
    await store.forget('', 'push_first');
    expect(store.pending(''), 'push_second');
    await store.forget('', 'push_second');
    expect(store.pending(''), isNull);
  });
}

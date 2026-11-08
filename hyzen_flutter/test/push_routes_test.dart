import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/notifications/push_service.dart';
void main() {
  test('notification routes reject external and administrator destinations', () {
    expect(safePushRoute('/study'), '/study');
    expect(safePushRoute('https://example.org'), '/notifications');
    expect(safePushRoute('/admin/push'), '/notifications');
    expect(safePushRoute(null), '/notifications');
  });
}

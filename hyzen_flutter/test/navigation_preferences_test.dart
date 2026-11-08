import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/app/providers.dart';
import 'package:hyzen_pharmd/core/widgets/navigation_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('font and dock controls persist independently across restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer make() => ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    var c = make();
    await c.read(textSizeProvider.notifier).set(24);
    c.read(dockSizeProvider.notifier).set(.85);
    c.read(dockThemeProvider.notifier).set('light');
    expect(c.read(textSizeProvider), 24);
    expect(c.read(dockSizeProvider), .85);
    await c.read(textSizeProvider.notifier).set(6);
    expect(c.read(dockThemeProvider), 'light');
    c.dispose();
    c = make();
    expect(c.read(textSizeProvider), 6);
    expect(c.read(dockSizeProvider), .85);
    expect(c.read(dockThemeProvider), 'light');
    c.dispose();
  });
}

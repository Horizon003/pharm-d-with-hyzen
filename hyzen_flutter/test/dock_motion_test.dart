import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/app/providers.dart';
import 'package:hyzen_pharmd/core/theme/app_theme.dart';
import 'package:hyzen_pharmd/core/widgets/main_dock.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'dock rapid selection stays within narrow bounds reduced=$reduced',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        var path = '/home';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 700),
                  disableAnimations: reduced,
                ),
                child: StatefulBuilder(
                  builder: (context, setState) => Scaffold(
                    bottomNavigationBar: MainDock(
                      path: path,
                      onSelected: (d) => setState(() => path = d.route),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final destination in [
          ...DockDestination.values.reversed,
          ...DockDestination.values,
        ]) {
          final target = find.byKey(ValueKey('dock-${destination.name}'));
          final gesture = await tester.startGesture(tester.getCenter(target));
          await tester.pump(const Duration(milliseconds: 40));
          if (reduced) {
            expect(
              tester
                  .widget<AnimatedScale>(
                    find.descendant(
                      of: target,
                      matching: find.byType(AnimatedScale),
                    ),
                  )
                  .scale,
              1,
            );
          }
          await gesture.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          for (final d in DockDestination.values) {
            final rect = tester.getRect(find.byKey(ValueKey('dock-${d.name}')));
            expect(rect.width, greaterThanOrEqualTo(48 - 1e-6));
            expect(rect.height, greaterThanOrEqualTo(48 - 1e-6));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

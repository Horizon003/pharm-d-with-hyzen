import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_screen.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_time_artwork.dart';

void main() {
  for (final hour in [5, 8, 11, 14, 17, 20]) {
    testWidgets('phase refresh at $hour without remounting', (tester) async {
      var now = DateTime(2026, 11, 7, hour - 1, 59, 59);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [homeClockProvider.overrideWithValue(() => now)],
          child: MaterialApp(
            home: HomePhaseArtwork(
              height: 100,
              builder: (_, phase) => Text(phase.label),
            ),
          ),
        ),
      );
      expect(find.text(HomeTimePhase.at(now).label), findsOneWidget);
      now = DateTime(2026, 11, 7, hour);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(HomeTimePhase.at(now).label), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
  testWidgets('resumed app refreshes after timezone change', (tester) async {
    var now = DateTime(2026, 11, 7, 6);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeClockProvider.overrideWithValue(() => now)],
        child: MaterialApp(
          home: HomePhaseArtwork(
            height: 100,
            builder: (_, phase) => Text(phase.label),
          ),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 11, 7, 22);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Night'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

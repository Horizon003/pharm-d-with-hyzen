import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/core/theme/app_theme.dart';
import 'package:hyzen_pharmd/core/widgets/press_feedback.dart';
import 'package:hyzen_pharmd/core/widgets/common.dart';

void main() {
  test('reference palette remains light and preserves readable contrast', () {
    double contrast(Color a, Color b) {
      final light = a.computeLuminance();
      final dark = b.computeLuminance();
      return ((light > dark ? light : dark) + .05) /
          ((light > dark ? dark : light) + .05);
    }

    expect(
      AppTheme.light(Colors.purple).colorScheme,
      AppTheme.light().colorScheme,
    );
    expect(AppTheme.dark(Colors.blue).colorScheme, AppTheme.dark().colorScheme);
    expect(AppTheme.dark().brightness, Brightness.light);
    expect(AppTheme.light().textTheme.bodyMedium?.fontFamily, 'Outfit');
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      for (final surface in [
        const Color(0xFFFAFAFC),
        scheme.surface,
        scheme.surfaceContainer,
      ]) {
        expect(contrast(scheme.onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(scheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        contrast(scheme.primary, scheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  testWidgets('reduced motion retains taps and never scales pressed controls', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: HPressFeedback(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('Study'),
              ),
            ),
          ),
        ),
      ),
    );
    final pointer = await tester.startGesture(
      tester.getCenter(find.text('Study')),
    );
    await tester.pump();
    final animation = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(animation.scale, 1);
    expect(animation.duration, Duration.zero);
    await pointer.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
  testWidgets(
    'long resource title and loading placeholder settle without idle tickers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 160,
              child: Column(
                children: const [
                  HMarqueeText(
                    'Pharmaceutical chemistry and medicinal compounds',
                  ),
                  Skeleton(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.byType(Tooltip), findsOneWidget);
    },
  );
}

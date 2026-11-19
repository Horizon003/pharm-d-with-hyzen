import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/core/widgets/polish_ui.dart';
import 'package:hyzen_pharmd/core/widgets/slide_continue.dart';

void main() {
  testWidgets('Continue follows a real drag and resets after a short drag', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: SlideContinue(
                label: 'Continue',
                semanticLabel: 'Continue onboarding',
                onComplete: () => completions++,
              ),
            ),
          ),
        ),
      ),
    );
    final track = find.byKey(const ValueKey('onboarding-slide'));
    final thumb = find.byIcon(Icons.arrow_forward_rounded);
    final start = tester.getCenter(thumb);
    final shortDrag = await tester.startGesture(start);
    await shortDrag.moveBy(const Offset(42, 0));
    await shortDrag.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(tester.getCenter(thumb).dx, greaterThan(start.dx));
    await shortDrag.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(thumb), start);
    expect(completions, 0);

    final cancelledDrag = await tester.startGesture(start);
    await cancelledDrag.moveBy(const Offset(200, 0));
    await cancelledDrag.cancel();
    await tester.pumpAndSettle();
    expect(tester.getCenter(thumb), start);
    expect(completions, 0);

    await tester.dragFrom(start, const Offset(245, 0));
    await tester.pumpAndSettle();
    expect(completions, 1);
    await tester.tap(track);
    expect(completions, 1);
  });

  testWidgets(
    'ambient art repeats and honors visibility, lifecycle and motion settings',
    (tester) async {
      const art = ValueKey('hero-art');
      Future<void> show({
        bool visible = true,
        bool reduced = false,
        bool enabled = true,
      }) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TickerMode(
              enabled: visible,
              child: Center(
                child: HSoftArt(
                  loop: true,
                  enabled: enabled,
                  child: const SizedBox(key: art, width: 50, height: 50),
                ),
              ),
            ),
          ),
        ),
      );
      Offset position() => tester.getCenter(find.byKey(art));
      Future<void> expectStill() async {
        final current = position();
        await tester.pump(const Duration(milliseconds: 1500));
        expect(position(), current);
      }

      await show();
      final initial = position();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(position(), isNot(initial));
      await tester.pump(const Duration(milliseconds: 6000));
      expect((position() - initial).distance, greaterThan(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await expectStill();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      final resumed = position();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(position(), isNot(resumed));

      await show(visible: false);
      await expectStill();
      await show(reduced: true);
      await expectStill();
      await show(enabled: false);
      await expectStill();
    },
  );
}

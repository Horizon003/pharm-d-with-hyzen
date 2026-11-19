import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/core/theme/app_theme.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'transparent route shields old content during push/pop reduced=$reduced',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        const capture = ValueKey('transition-capture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: child!,
              ),
              home: const Scaffold(backgroundColor: Colors.red),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<Color?> sample() => tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final offset = (100 * image.width + 100) * 4;
          final color = Color.fromARGB(
            data!.getUint8(offset + 3),
            data.getUint8(offset),
            data.getUint8(offset + 1),
            data.getUint8(offset + 2),
          );
          image.dispose();
          return color;
        });

        expect((await sample())!.toARGB32(), Colors.red.toARGB32());
        final next = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            backgroundColor: Colors.transparent,
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Text('Next page'),
            ),
          ),
        );
        navigator.currentState!.push(next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        // Sampling uncovered space proves the previous page cannot bleed through
        // either the transparent Scaffold or the content fade at mid-transition.
        expect((await sample())!.toARGB32(), Colors.white.toARGB32());
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect((await sample())!.toARGB32(), Colors.white.toARGB32());
        await tester.pumpAndSettle();
        expect((await sample())!.toARGB32(), Colors.red.toARGB32());
        expect(tester.takeException(), isNull);
      },
    );
  }
}

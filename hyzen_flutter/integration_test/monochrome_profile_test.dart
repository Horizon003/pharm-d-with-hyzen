import 'package:flutter/foundation.dart' show listEquals;
import 'package:hyzen_pharmd/features/study_progress/study_calendar.dart';
import 'package:hyzen_pharmd/features/study_progress/study_progress_screen.dart';
import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/app/app.dart';
import 'package:hyzen_pharmd/app/providers.dart';
import 'package:hyzen_pharmd/app/router.dart';
import 'package:hyzen_pharmd/core/widgets/polish_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:hyzen_pharmd/features/academics/presentation/library_screens.dart';
import 'package:hyzen_pharmd/features/downloads/presentation/downloads_screen.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_screen.dart';
import 'package:hyzen_pharmd/features/pdf_studio/data/studio_pdf_engine.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/pdf_studio_screen.dart';
import 'package:hyzen_pharmd/features/profile/presentation/profile_screens.dart';
import 'package:hyzen_pharmd/features/shop/presentation/shop_screens.dart';
import 'package:hyzen_pharmd/features/study_progress/campus_rank_screen.dart';
import 'package:hyzen_pharmd/features/study_progress/study_goals_screen.dart';
import 'package:hyzen_pharmd/features/study_progress/study_streak_screen.dart';
import 'package:hyzen_pharmd/features/viewer/offline_pdf.dart';
import 'package:hyzen_pharmd/main_account_review.dart' as fixture;
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Let the engine schedule its own animation frames. A fixed number of
  // awaited pumps ties real elapsed time to emulator rendering throughput.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  testWidgets(
    'native reference profile: home, retained tabs, scroll, routes and PDF',
    (tester) async {
      _checkpoint('starting fixture');
      await fixture.main().timeout(const Duration(seconds: 20));
      await _waitFor(() => find.byType(HyzenApp).evaluate().isNotEmpty, 'app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HyzenApp)),
      );
      final router = container.read(routerProvider);
      final ambient = container.read(
        boolPrefProvider('pref_ambient_motion').notifier,
      );
      ambient.set(true);
      tester.platformDispatcher.clearTextScaleFactorTestValue();

      router.go('/home');
      final hero = find.byKey(const ValueKey('home-hero-art'));
      await _waitFor(() => hero.evaluate().isNotEmpty, 'Home hero');
      final art = tester.widget<HSoftArt>(
        find.ancestor(of: hero, matching: find.byType(HSoftArt)).first,
      );
      expect(art.loop && art.enabled, isTrue);
      await _sample(binding, 'ambient_hero', () async {
        final initial = tester.getCenter(hero);
        var moved = false;
        final elapsed = Stopwatch()..start();
        while (elapsed.elapsed < const Duration(seconds: 6)) {
          await _wait(const Duration(milliseconds: 250));
          moved |= (tester.getCenter(hero) - initial).distance > 0.25;
        }
        expect(
          moved,
          isTrue,
          reason: 'Home artwork must animate in the sample',
        );
      });

      await _sample(binding, 'tab_navigation', () async {
        for (var i = 0; i < 5; i++) {
          for (final path in [
            '/home',
            '/study',
            '/pdf-studio',
            '/downloads',
            '/shop',
          ]) {
            await _showRoute(router, path);
          }
        }
      });

      await _showRoute(router, '/home');
      await _sample(binding, 'home_scroll', () async {
        for (var i = 0; i < 5; i++) {
          for (final dy in [-450.0, 450.0]) {
            final scroll = find.byType(CustomScrollView).first;
            await tester.fling(scroll, Offset(0, dy), 900);
            await _wait(const Duration(milliseconds: 650));
          }
        }
      });

      await _sample(binding, 'route_transitions', () async {
        for (final path in [
          '/study-goals',
          '/study-streak',
          '/campus-rank',
          '/profile',
          '/settings',
        ]) {
          _checkpoint('opening transition $path');
          await _showRoute(router, path, push: true);
          if (router.canPop()) {
            _checkpoint('popping transition $path');
            router.pop();
            await _waitFor(() => _routeVisible('/home'), 'return after $path');
            await _wait();
          } else {
            _checkpoint('returning Home from root $path');
            await _showRoute(router, '/home');
          }
        }
      });

      _checkpoint('creating PDF fixture');
      final path = await StudioPdfEngine.textToPdf(
        'Pharm D profile fixture\nPharmacology revision',
      ).timeout(const Duration(seconds: 15));
      expect(
        await StudioPdfEngine.pageCount(
          path,
        ).timeout(const Duration(seconds: 10)),
        1,
      );
      await _sample(binding, 'pdf_open', () async {
        await _showRoute(router, '/pdf-studio');
        final nav = Navigator.of(tester.element(find.byType(PdfStudioScreen)));
        var pdfOpened = false;
        unawaited(
          nav.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Profile PDF')),
                body: OfflinePdf(path: path, onOpened: () => pdfOpened = true),
              ),
            ),
          ),
        );
        await _waitFor(() => pdfOpened, 'first rendered PDF frame');
        nav.pop();
        await _wait();
      });

      // Readback runs after profiling with the decorative ticker idle.
      _checkpoint('preparing screenshot surface');
      ambient.set(false);
      await _wait();
      await binding.convertFlutterSurfaceToImage().timeout(
        const Duration(seconds: 15),
      );
      container.read(themeModeProvider.notifier).set(ThemeMode.light);
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
      List<int>? previousCapture;
      for (final path in [
        '/home',
        '/study',
        '/pdf-studio',
        '/downloads',
        '/profile',
        '/settings',
        '/study-goals',
        '/study-progress',
        '/study-streak',
        '/study-calendar',
      ]) {
        await _showRoute(router, path);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 15),
        );
        // PixelCopy must see the settled raster frame, not merely a mounted
        // route. SwiftShader can trail the UI tree by more than 800 ms.
        await binding.endOfFrame;
        await _wait(const Duration(milliseconds: 1500));
        final name = 'light-${path.substring(1)}';
        _checkpoint('capturing $name');
        var bytes = await binding
            .takeScreenshot(name)
            .timeout(const Duration(seconds: 15));
        // PixelCopy can return the last converted surface even after the new
        // route is current. Explicitly repaint and retry outside timing samples;
        // keep rejecting identical captures rather than publishing stale pixels.
        for (
          var retry = 0;
          previousCapture != null &&
              listEquals(previousCapture, bytes) &&
              retry < 3;
          retry++
        ) {
          _checkpoint('retrying stale screenshot $name');
          for (final view in binding.renderViews) {
            view.markNeedsPaint();
          }
          binding.scheduleFrame();
          await tester.pump(const Duration(milliseconds: 100));
          await _wait(const Duration(milliseconds: 1500));
          bytes = await binding
              .takeScreenshot(name)
              .timeout(const Duration(seconds: 15));
        }
        expect(bytes, isNotEmpty, reason: 'Screenshot $name must contain data');
        expect(
          previousCapture == null || !listEquals(previousCapture, bytes),
          isTrue,
          reason: '$name must not reuse the previous screen frame',
        );
        previousCapture = bytes;
      }
      expect(tester.takeException(), isNull);
      binding.reportData!['profile_complete'] = true;
      _checkpoint('complete');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

void _checkpoint(String message) => debugPrint('Native profile: $message');

Future<void> _wait([Duration duration = const Duration(milliseconds: 380)]) =>
    Future<void>.delayed(duration);

Future<void> _waitFor(bool Function() predicate, String description) async {
  final elapsed = Stopwatch()..start();
  while (!predicate()) {
    if (elapsed.elapsed >= const Duration(seconds: 12)) {
      throw TimeoutException('Waiting for $description');
    }
    await _wait(const Duration(milliseconds: 100));
  }
}

const _screens = {
  '/home': HomeScreen,
  '/study': StudyHubScreen,
  '/pdf-studio': PdfStudioScreen,
  '/downloads': DownloadsScreen,
  '/shop': ShopScreen,
  '/study-goals': StudyGoalsScreen,
  '/study-calendar': StudyCalendarScreen,
  '/study-progress': StudyProgressScreen,
  '/study-streak': StudyStreakScreen,
  '/campus-rank': CampusRankScreen,
  '/profile': ProfileScreen,
  '/settings': SettingsScreen,
};

bool _routeVisible(String path) => find
    .byType(_screens[path]!)
    .evaluate()
    .any((element) => ModalRoute.of(element)?.isCurrent == true);

Future<void> _showRoute(
  GoRouter router,
  String path, {
  bool push = false,
}) async {
  if (push) {
    unawaited(router.push<void>(path));
  } else {
    router.go(path);
  }
  await _waitFor(() => _routeVisible(path), 'rendered route $path');
  await _wait();
}

Future<void> _sample(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
  Future<void> Function() action,
) async {
  // Engine timings arrive in batches. Register a fresh listener for each run
  // and leave bounded time for the final batch without forcing extra frames.
  await _wait(const Duration(milliseconds: 1100));
  _checkpoint('sampling $name');
  final frames = <FrameTiming>[];
  final collect = frames.addAll;
  binding.addTimingsCallback(collect);
  try {
    await action().timeout(const Duration(seconds: 45));
    await _wait(const Duration(milliseconds: 1200));
  } finally {
    binding.removeTimingsCallback(collect);
  }
  expect(frames, isNotEmpty, reason: '$name must capture engine timings');
  binding.reportData ??= {};
  binding.reportData![name] = FrameTimingSummarizer(frames).summary;
  _checkpoint('$name recorded ${frames.length} frames');
}

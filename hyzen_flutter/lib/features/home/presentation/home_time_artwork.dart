import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart' show homeClockProvider;

/// The user's six supplied landscape images use LOCAL device time, independently
/// from the selected light/dark app appearance.
enum HomeTimePhase {
  earlyMorning('Early Morning', 'Good Morning', 'early_morning.webp'),
  morning('Morning', 'Good Day', 'late_morning.webp'),
  afternoon('Afternoon', 'Good Afternoon', 'afternoon.webp'),
  evening('Evening', 'Good Evening', 'late_afternoon.webp'),
  night('Night', 'Good Night', 'evening.webp'),
  lateNight('Late Night', 'Good Night', 'night.webp');

  const HomeTimePhase(this.label, this.greeting, this.file);
  final String label;
  final String greeting;
  final String file;

  String get asset => 'assets/home_backgrounds/$file';

  static HomeTimePhase at(DateTime local) {
    final hour = local.hour;
    if (hour >= 5 && hour < 8) return HomeTimePhase.earlyMorning;
    if (hour >= 8 && hour < 12) return HomeTimePhase.morning;
    if (hour >= 12 && hour < 16) return HomeTimePhase.afternoon;
    if (hour >= 16 && hour < 19) return HomeTimePhase.evening;
    if (hour >= 19 && hour < 23) return HomeTimePhase.night;
    return HomeTimePhase.lateNight;
  }
}

/// Shared, injectable wall clock. Pause timers when there are no listeners or
/// the app is backgrounded; re-evaluate timezone and time on resume.
final homePhaseClockProvider =
    ChangeNotifierProvider.autoDispose<HomePhaseClock>((ref) {
      final clock = HomePhaseClock(ref.watch(homeClockProvider));
      ref.onCancel(clock.suspend);
      ref.onResume(clock.refresh);
      return clock;
    });

class HomePhaseClock extends ChangeNotifier with WidgetsBindingObserver {
  HomePhaseClock(this.now) {
    value = now();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }
  final DateTime Function() now;
  late DateTime value;
  Timer? _timer;
  bool _disposed = false;
  void suspend() {
    _timer?.cancel();
  }

  void _schedule() {
    suspend();
    final next = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute + 1,
    );
    final delay = next.difference(value);
    _timer = Timer(delay.isNegative ? Duration.zero : delay, refresh);
  }

  void refresh() {
    if (_disposed) return;
    value = now();
    notifyListeners();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    } else {
      suspend();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    suspend();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class HomePhaseArtwork extends ConsumerWidget {
  const HomePhaseArtwork({
    super.key,
    required this.height,
    required this.builder,
  });
  final double height;
  final Widget Function(BuildContext context, HomeTimePhase phase) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(homePhaseClockProvider).value;
    return SizedBox(
      height: height,
      child: builder(context, HomeTimePhase.at(time)),
    );
  }
}

class HomeLandscape extends StatelessWidget {
  const HomeLandscape({super.key, required this.phase, this.height = 220});
  final HomeTimePhase phase;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).scaffoldBackgroundColor;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 320),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, if (current != null) current],
            ),
            child: ShaderMask(
              key: ValueKey(phase),
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  base.withValues(alpha: 0),
                  const Color(0xFFFFFFFF),
                  const Color(0xFFFFFFFF),
                  base.withValues(alpha: 0),
                ],
                stops: const [0, .18, .78, 1],
              ).createShader(bounds),
              child: Image.asset(
                phase.asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => ColoredBox(color: base),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const [Color(0x22000000), Color(0x00000000), Color(0x44000000)]
                      : const [Color(0x120B1D35), Color(0x00000000), Color(0x1A112846)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

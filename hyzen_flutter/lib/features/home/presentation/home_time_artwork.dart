import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart' show homeClockProvider;

/// The user's six supplied landscape images use LOCAL device time, independently
/// from the selected light/dark app appearance.
enum HomeTimePhase {
  earlyMorning('Early Morning', 'Good Morning', 'early_morning.webp'),
  lateMorning('Late Morning', 'Good Day', 'late_morning.webp'),
  afternoon('Afternoon', 'Good Afternoon', 'afternoon.webp'),
  lateAfternoon('Late Afternoon', 'Good Afternoon', 'late_afternoon.webp'),
  evening('Evening', 'Good Evening', 'evening.webp'),
  night('Night', 'Good Night', 'night.webp');

  const HomeTimePhase(this.label, this.greeting, this.file);
  final String label;
  final String greeting;
  final String file;

  String get asset => 'assets/home_backgrounds/$file';

  static HomeTimePhase at(DateTime local) {
    final hour = local.hour;
    if (hour >= 5 && hour < 8) return HomeTimePhase.earlyMorning;
    if (hour >= 8 && hour < 11) return HomeTimePhase.lateMorning;
    if (hour >= 11 && hour < 14) return HomeTimePhase.afternoon;
    if (hour >= 14 && hour < 17) return HomeTimePhase.lateAfternoon;
    if (hour >= 17 && hour < 20) return HomeTimePhase.evening;
    return HomeTimePhase.night;
  }
}

/// One clock for the Home page. Recomputes on resume and once per minute,
/// including while Home remains open across a phase boundary. Timers are
/// cancelled with the widget to avoid leaked fake timers in widget tests.
class HomePhaseArtwork extends ConsumerStatefulWidget {
  const HomePhaseArtwork({
    super.key,
    required this.height,
    required this.builder,
  });

  final double height;
  final Widget Function(BuildContext context, HomeTimePhase phase) builder;

  @override
  ConsumerState<HomePhaseArtwork> createState() => _HomePhaseArtworkState();
}

class _HomePhaseArtworkState extends ConsumerState<HomePhaseArtwork>
    with WidgetsBindingObserver {
  Timer? _minuteTimer;
  DateTime _clock = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _clock = DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _clock = DateTime.now());
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The provider is overrideable for deterministic phase-boundary tests.
    final time = ref.watch(homeClockProvider)();
    final phase = HomeTimePhase.at(_clock.year > 0 ? time : DateTime.now());
    return SizedBox(height: widget.height, child: widget.builder(context, phase));
  }
}

class HomeLandscape extends StatelessWidget {
  const HomeLandscape({super.key, required this.phase, this.height = 220});
  final HomeTimePhase phase;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, if (current != null) current],
            ),
            child: Image.asset(
              phase.asset,
              key: ValueKey(phase),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF1A3C64)),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [Color(0xDD030407), Color(0x33000000), Color(0xC9000000)]
                    : const [Color(0x00000000), Color(0x00000000), Color(0x4F112846)],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

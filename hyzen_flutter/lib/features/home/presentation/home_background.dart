import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_time_artwork.dart';

class HomeAtmosphere extends ConsumerWidget {
  const HomeAtmosphere({super.key, required this.child, this.content = false});
  final Widget child;
  final bool content;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).scaffoldBackgroundColor;
    if (content) return ColoredBox(color: base, child: child);
    final phase = HomeTimePhase.at(ref.watch(homePhaseClockProvider).value);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final sky =
        MediaQuery.paddingOf(context).top +
        72 +
        (scale > 1.5 ? 370 * scale.clamp(1, 2) : 230);
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: base)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: sky,
          child: AnimatedSwitcher(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 500),
            child: Stack(
              key: ValueKey(phase),
              fit: StackFit.expand,
              children: [
                Image.asset(
                  phase.asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => ColoredBox(color: base),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? const [
                              Color(0xD9000000),
                              Color(0x66000000),
                              Color(0xF0000000),
                            ]
                          : [
                              const Color(0x300B1D35),
                              const Color(0x220B1D35),
                              base.withValues(alpha: .85),
                            ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

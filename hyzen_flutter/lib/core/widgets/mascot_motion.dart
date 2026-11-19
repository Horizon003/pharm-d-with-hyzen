import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// One finite reaction when the semantic state changes; no idle animation.
enum HyzenMascotState { welcome, peeking, studying, downloading, success }

class HyzenMascot extends StatelessWidget {
  const HyzenMascot({
    super.key,
    required this.state,
    this.size = 220,
    this.semanticLabel = 'Hyzen panda mascot',
    this.loop = true,
  });
  final HyzenMascotState state;
  final double size;
  final String semanticLabel;
  // Retained for callers that explicitly request a static pose.
  final bool loop;
  @override
  Widget build(BuildContext context) {
    final asset = switch (state) {
      HyzenMascotState.welcome => 'mascot_idle_welcome',
      HyzenMascotState.peeking => 'mascot_peeking',
      HyzenMascotState.studying => 'mascot_studying',
      HyzenMascotState.downloading => 'mascot_downloading',
      HyzenMascotState.success => 'mascot_success_wave',
    };
    final still =
        !loop ||
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.of(context);
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size * 1.5,
        child: AnimatedSwitcher(
          duration: still ? Duration.zero : HMotion.medium,
          switchInCurve: HMotion.curve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(0, .025), end: Offset.zero),
              ),
              child: child,
            ),
          ),
          child: Image.asset(
            'assets/mascot/$asset.png',
            key: ValueKey(state),
            width: size,
            height: size * 1.5,
            fit: BoxFit.contain,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(1, 1024),
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

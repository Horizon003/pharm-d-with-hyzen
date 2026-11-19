import 'package:flutter/material.dart';

import 'tokens.dart';

/// Each route owns an opaque canvas, including during its enter/exit motion.
/// Several screens intentionally use transparent Scaffolds for pastel surfaces;
/// fading those Scaffolds directly lets the previous screen's text show through.
class HyzenPageTransitions extends PageTransitionsBuilder {
  const HyzenPageTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final eased = animation.drive(CurveTween(curve: HMotion.curve));
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: reduced
          ? child
          : FadeTransition(
              opacity: eased,
              child: SlideTransition(
                position: eased.drive(
                  Tween(begin: const Offset(.02, 0), end: Offset.zero),
                ),
                child: child,
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

/// Controlled depth for the reference Home surfaces.
/// Light mode uses a soft charcoal drop shadow; dark mode pairs a restrained
/// white rim highlight with a darker underside so surfaces remain readable.
List<BoxShadow> homeDepthShadows(
  BuildContext context, {
  double blur = 14,
  double y = 6,
  double opacity = 1,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (dark) {
    return [
      BoxShadow(
        color: Colors.white.withValues(alpha: .12 * opacity),
        blurRadius: 5,
        spreadRadius: .2,
        offset: const Offset(0, -1),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: .48 * opacity),
        blurRadius: blur,
        spreadRadius: -1,
        offset: Offset(0, y),
      ),
    ];
  }
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: .18 * opacity),
      blurRadius: blur,
      spreadRadius: -1,
      offset: Offset(0, y),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: .78 * opacity),
      blurRadius: 5,
      spreadRadius: .2,
      offset: const Offset(0, -1),
    ),
  ];
}

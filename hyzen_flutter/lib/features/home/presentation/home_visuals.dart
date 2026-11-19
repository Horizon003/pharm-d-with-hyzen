import 'package:flutter/material.dart';

/// A small neutral lift on light surfaces; dark depth uses borders and tone.
List<BoxShadow> homeDepthShadows(
  BuildContext context, {
  double blur = 4,
  double y = 1,
  double opacity = 1,
}) => Theme.of(context).brightness == Brightness.dark
    ? const []
    : [
        BoxShadow(
          color: Colors.black.withValues(alpha: .045 * opacity),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

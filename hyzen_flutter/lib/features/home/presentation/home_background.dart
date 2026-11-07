import 'package:flutter/material.dart';

class HomeAtmosphere extends StatelessWidget {
  const HomeAtmosphere({super.key, required this.child, this.content = false});
  final Widget child;
  final bool content;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF050507) : const Color(0xFFE8F1FB);
    if (content) return ColoredBox(color: base, child: child);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final sky = MediaQuery.paddingOf(context).top + 72 +
        (scale > 1.5 ? 370 * scale.clamp(1, 2) : 230);
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: base)),
      Positioned(top: 0, left: 0, right: 0, height: sky, child: ColoredBox(color: dark ? Colors.black : const Color(0xFFE8F1FB))),
      child,
    ]);
  }
}

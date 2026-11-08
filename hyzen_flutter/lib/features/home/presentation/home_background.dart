import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeAtmosphere extends ConsumerWidget {
  const HomeAtmosphere({super.key, required this.child, this.content = false});
  final Widget child;
  final bool content;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    return ColoredBox(color: base, child: child);
  }
}

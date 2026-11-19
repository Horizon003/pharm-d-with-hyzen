import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tokens.dart';

class HomeAtmosphere extends ConsumerWidget {
  const HomeAtmosphere({super.key, required this.child, this.content = false});
  final Widget child;
  final bool content;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: hPageGradient),
      child: child,
    );
  }
}

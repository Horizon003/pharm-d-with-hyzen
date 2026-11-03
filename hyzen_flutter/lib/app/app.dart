import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/brand.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palettes.dart';
import 'providers.dart';
import 'router.dart';
import '../features/viewer/external_files.dart';

class HyzenApp extends ConsumerWidget {
  const HyzenApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(doublePrefProvider('pref_text_scale'));
    final reduceMotion = ref.watch(boolPrefProvider('pref_reduce_motion'));
    return MaterialApp.router(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(ref.watch(paletteColorProvider)),
      darkTheme: AppTheme.dark(ref.watch(paletteColorProvider)),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(1);
        final effectiveScale =
            (systemScale * textScale).clamp(0.85, 2.0).toDouble();
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(effectiveScale),
            disableAnimations: media.disableAnimations || reduceMotion,
          ),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: ExternalOpenGate(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

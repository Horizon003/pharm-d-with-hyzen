import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/brand.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palettes.dart';
import 'providers.dart';
import '../features/notifications/push_binding.dart';
import '../features/study_progress/study_tracker.dart';
import 'router.dart';
import '../features/study_progress/study_notifications.dart';
import '../features/viewer/external_files.dart';

class HyzenApp extends ConsumerWidget {
  const HyzenApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    StudyNotificationScheduler.instance.bindOpenHandler((route) {
      WidgetsBinding.instance.addPostFrameCallback((_) => router.go(route));
    });
    return PushBinding(
      child: MaterialApp.router(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(ref.watch(paletteColorProvider)),
        darkTheme: AppTheme.dark(ref.watch(paletteColorProvider)),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: _AppTextScaler(
              MediaQuery.textScalerOf(context),
              ref.watch(textSizeProvider) / 13,
            ),
          ),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Listener(
                  onPointerDown: (_) =>
                      ref.read(studyTrackerProvider).interaction(),
                  onPointerSignal: (_) =>
                      ref.read(studyTrackerProvider).interaction(),
                  child: ExternalOpenGate(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize * factor);
  @override
  double get textScaleFactor => scale(14) / 14;
}

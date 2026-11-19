import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/brand.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../features/notifications/push_binding.dart';
import '../features/study_progress/study_tracker.dart';
import 'router.dart';
import '../core/widgets/display_preferences.dart';
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
    final elementScale = ref.watch(displayScaleProvider('ui_element_scale'));
    final textScale = ref.watch(displayScaleProvider('ui_text_scale'));
    return PushBinding(
      child: MaterialApp.router(
        title: Brand.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light().copyWith(
          visualDensity: VisualDensity(
            horizontal: (elementScale - 1) * 12,
            vertical: (elementScale - 1) * 12,
          ),
        ),
        themeMode: ThemeMode.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: UserTextScaler(
              MediaQuery.textScalerOf(context),
              textScale,
            ),
          ),
          child: UiDensity(
            factor: elementScale,
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: hPageGradient),
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
      ),
    );
  }
}

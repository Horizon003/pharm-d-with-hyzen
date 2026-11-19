import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class DockThemePreference extends Notifier<String> {
  @override
  String build() =>
      ref.watch(sharedPrefsProvider).getString('dock_theme') ?? 'follow';
  void set(String value) {
    if (!['follow', 'light', 'dark'].contains(value)) return;
    state = value;
    ref.read(sharedPrefsProvider).setString('dock_theme', value);
  }
}

final dockThemeProvider = NotifierProvider<DockThemePreference, String>(
  DockThemePreference.new,
);

class DockSizePreference extends Notifier<double> {
  @override
  double build() =>
      (ref.watch(sharedPrefsProvider).getDouble('dock_size') ?? .9).clamp(
        .85,
        1.25,
      );
  void set(double value) {
    state = value.clamp(.85, 1.25);
    ref.read(sharedPrefsProvider).setDouble('dock_size', state);
  }
}

final dockSizeProvider = NotifierProvider<DockSizePreference, double>(
  DockSizePreference.new,
);

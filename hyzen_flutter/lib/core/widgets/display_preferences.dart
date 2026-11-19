import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';

class DisplayScale extends FamilyNotifier<double, String> {
  @override
  double build(String key) =>
      (ref.watch(sharedPrefsProvider).getDouble(key) ?? 1).clamp(
        .9,
        key == 'ui_text_scale' ? 1.25 : 1.15,
      );
  void set(double value) {
    state = value.clamp(.9, arg == 'ui_text_scale' ? 1.25 : 1.15);
    ref.read(sharedPrefsProvider).setDouble(arg, state);
  }
}

final displayScaleProvider =
    NotifierProvider.family<DisplayScale, double, String>(DisplayScale.new);

class UiDensity extends InheritedWidget {
  const UiDensity({super.key, required this.factor, required super.child});
  final double factor;
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiDensity>()?.factor ?? 1;
  @override
  bool updateShouldNotify(UiDensity oldWidget) => factor != oldWidget.factor;
}

class UserTextScaler extends TextScaler {
  const UserTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(14) / 14;
}

class DisplayControls extends ConsumerWidget {
  const DisplayControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final item in [
        ('ui_text_scale', 'Text size', 1.25),
        ('ui_element_scale', 'Element size', 1.15),
      ])
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.$2} · ${(ref.watch(displayScaleProvider(item.$1)) * 100).round()}%',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Slider(
                key: ValueKey(item.$1),
                min: .9,
                max: item.$3,
                divisions: item.$1 == 'ui_text_scale' ? 7 : 5,
                value: ref.watch(displayScaleProvider(item.$1)),
                label:
                    '${(ref.watch(displayScaleProvider(item.$1)) * 100).round()}%',
                onChanged: ref.read(displayScaleProvider(item.$1).notifier).set,
              ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Adjusts app text and controls. Your Android font setting stays active.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () {
            ref.read(displayScaleProvider('ui_text_scale').notifier).set(1);
            ref.read(displayScaleProvider('ui_element_scale').notifier).set(1);
          },
          child: const Text('Reset sizes'),
        ),
      ),
    ],
  );
}

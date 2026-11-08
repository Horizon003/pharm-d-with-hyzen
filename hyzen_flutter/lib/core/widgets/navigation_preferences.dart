import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'main_dock.dart';

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
  double build() => (ref.watch(sharedPrefsProvider).getDouble('dock_size') ?? 1)
      .clamp(.85, 1.25);
  void set(double value) {
    state = value.clamp(.85, 1.25);
    ref.read(sharedPrefsProvider).setDouble('dock_size', state);
  }
}

final dockSizeProvider = NotifierProvider<DockSizePreference, double>(
  DockSizePreference.new,
);

class AppearanceControls extends ConsumerStatefulWidget {
  const AppearanceControls({super.key});
  @override
  ConsumerState<AppearanceControls> createState() => _AppearanceControlsState();
}

class _AppearanceControlsState extends ConsumerState<AppearanceControls> {
  String _preview = '/home';
  @override
  Widget build(BuildContext context) {
    final font = ref.watch(textSizeProvider),
        mode = ref.watch(dockThemeProvider),
        size = ref.watch(dockSizeProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Font Size · $font',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Slider(
            min: 6,
            max: 24,
            divisions: 18,
            value: font.toDouble(),
            label: '$font',
            onChanged: (v) =>
                ref.read(textSizeProvider.notifier).set(v.round()),
          ),
          const Text('Live preview: Your next study session starts here.'),
          const SizedBox(height: 24),
          Text(
            'Bottom navigation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          RadioGroup<String>(
            groupValue: mode,
            onChanged: (v) => ref.read(dockThemeProvider.notifier).set(v!),
            child: Column(
              children: [
                for (final m in [
                  ('follow', 'Follow App / System'),
                  ('light', 'Light Navigation'),
                  ('dark', 'Dark Navigation'),
                ])
                  RadioListTile<String>(title: Text(m.$2), value: m.$1),
              ],
            ),
          ),
          Text('Navigation size · ${(size * 100).round()}%'),
          Slider(
            min: .85,
            max: 1.25,
            divisions: 8,
            value: size,
            label: '${(size * 100).round()}%',
            onChanged: ref.read(dockSizeProvider.notifier).set,
          ),
          MainDock(
            path: _preview,
            onSelected: (d) => setState(() => _preview = d.route),
          ),
        ],
      ),
    );
  }
}

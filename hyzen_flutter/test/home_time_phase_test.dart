import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_time_artwork.dart';

void main() {
  test('six exact local-time windows change without gaps or overlaps', () {
    HomeTimePhase at(int hour, int minute) =>
        HomeTimePhase.at(DateTime(2026, 11, 7, hour, minute));
    expect(at(4, 59), HomeTimePhase.lateNight);
    expect(at(5, 0), HomeTimePhase.earlyMorning);
    expect(at(7, 59), HomeTimePhase.earlyMorning);
    expect(at(8, 0), HomeTimePhase.morning);
    expect(at(11, 59), HomeTimePhase.morning);
    expect(at(12, 0), HomeTimePhase.afternoon);
    expect(at(15, 59), HomeTimePhase.afternoon);
    expect(at(16, 0), HomeTimePhase.evening);
    expect(at(18, 59), HomeTimePhase.evening);
    expect(at(19, 0), HomeTimePhase.night);
    expect(at(22, 59), HomeTimePhase.night);
    expect(at(23, 0), HomeTimePhase.lateNight);
  });

  test('original six WebP filenames have unique, explicit asset paths', () {
    final paths = HomeTimePhase.values.map((phase) => phase.asset).toList();
    expect(paths.toSet().length, 6);
    for (final path in paths) {
      expect(path.startsWith('assets/home_backgrounds/'), true);
      expect(path.endsWith('.webp'), true);
    }
  });
}

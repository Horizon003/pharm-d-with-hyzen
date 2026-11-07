import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_time_artwork.dart';

void main() {
  test('six exact local-time windows change without gaps or overlaps', () {
    HomeTimePhase at(int hour, int minute) =>
        HomeTimePhase.at(DateTime(2026, 11, 7, hour, minute));
    expect(at(4, 59), HomeTimePhase.night);
    expect(at(5, 0), HomeTimePhase.earlyMorning);
    expect(at(7, 59), HomeTimePhase.earlyMorning);
    expect(at(8, 0), HomeTimePhase.lateMorning);
    expect(at(10, 59), HomeTimePhase.lateMorning);
    expect(at(11, 0), HomeTimePhase.afternoon);
    expect(at(13, 59), HomeTimePhase.afternoon);
    expect(at(14, 0), HomeTimePhase.lateAfternoon);
    expect(at(16, 59), HomeTimePhase.lateAfternoon);
    expect(at(17, 0), HomeTimePhase.evening);
    expect(at(19, 59), HomeTimePhase.evening);
    expect(at(20, 0), HomeTimePhase.night);
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

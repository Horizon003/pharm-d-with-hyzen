import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

const _scenarios = [
  'ambient_hero',
  'tab_navigation',
  'home_scroll',
  'route_transitions',
  'pdf_open',
];

Future<void> main() async {
  final report = File('qa/reference/native/frame-timings.json');
  if (await report.exists()) await report.delete();

  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (bytes.isEmpty) return false;
      final file = File('qa/reference/native/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      if (data == null || data['profile_complete'] != true) {
        throw StateError('Native profile did not complete.');
      }
      for (final name in _scenarios) {
        final sample = data[name];
        final count = sample is Map ? sample['frame_count'] : null;
        if (count is! int || count <= 0) {
          throw StateError('Native profile returned no frames for $name.');
        }
      }
      // Screenshots are already written above. Keep image bytes out of JSON.
      final timings = {for (final name in _scenarios) name: data[name]};
      await report.parent.create(recursive: true);
      await report.writeAsString(
        const JsonEncoder.withIndent('  ').convert(timings),
      );
    },
  );
}

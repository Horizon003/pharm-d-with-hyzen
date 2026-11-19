import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/admin/data/csv_files_native.dart';
import 'package:hyzen_pharmd/features/admin/data/data_files_native.dart';
import 'package:hyzen_pharmd/features/admin/domain/import_templates.dart';
import 'package:hyzen_pharmd/features/admin/domain/import_csv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.hyzen.pharmd/csv_files');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'native Excel template export preserves binary bytes and cancellation',
    () async {
      final bytes = importTemplateXlsx();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'saveFile');
            expect(call.arguments['bytes'], bytes);
            expect(call.arguments['text'], isNull);
            expect(
              call.arguments['mime'],
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            );
            return false;
          });
      expect(
        await saveDataBytes(
          'template.xlsx',
          bytes,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
        false,
      );
    },
  );
  test(
    'one malformed selected file does not discard valid CSV/Excel selections',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => [
              {
                'name': 'notes.csv',
                'bytes': Uint8List.fromList(utf8.encode(importTemplateCsv())),
              },
              {
                'name': 'broken.json',
                'bytes': Uint8List.fromList(utf8.encode('{broken')),
              },
              {'name': 'workbook.xlsx', 'bytes': importTemplateXlsx()},
            ],
          );
      final files = await pickCsvFiles();
      expect(files.length, 3);
      expect(files[0].error, isNull);
      expect(files[1].error, contains('broken.json'));
      expect(files[2].error, isNull);
      expect(parseCsv(files[2].text).length, 7);
    },
  );
  test(
    'lecture conflicts leave the existing link intact while new topics import',
    () {
      final rows = validateImport(
        'Professional Year,Semester,Subject,Topic,Link\nYear,Semester,Subject,ANS,https://youtu.be/first\nYear,Semester,Subject,ANS,https://youtu.be/second\nYear,Semester,Subject,CNS,https://youtu.be/third',
        'lecture.csv',
        defaultType: 'lectures',
      ).rows;
      final tree = <Map<String, dynamic>>[];
      var id = 0;
      final result = mergeLectureRows(
        tree,
        rows,
        () => '${id++}',
        batchId: 'batch',
      );
      expect(result.added, 2);
      expect(result.conflicts.single, contains('ANS'));
      expect(jsonEncode(tree), isNot(contains('https://youtu.be/second')));
      expect(undoImportNodes(tree, 'batch'), 2);
      expect(tree, isEmpty);
    },
  );
}

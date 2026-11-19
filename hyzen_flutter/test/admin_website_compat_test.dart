import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/admin/domain/import_csv.dart';
import 'package:hyzen_pharmd/features/admin/domain/import_formats.dart';
import 'package:hyzen_pharmd/features/admin/domain/import_templates.dart';

void main() {
  test('website JSON with UTF-8 BOM is accepted', () {
    final csv = dataFileCsv(
      'bom.json',
      Uint8List.fromList(utf8.encode('\uFEFF${importTemplateJson()}')),
    );
    expect(parseCsv(csv).length, 7);
  });
  test(
    'website batch markers remain undoable without touching later files',
    () {
      final tree = <Map<String, dynamic>>[
        {
          '_createdByBatch': 'old',
          'files': <Map<String, dynamic>>[
            {
              '_importBatch': 'old',
              'title': 'Imported',
              'pdfUrl': 'https://example.org/old.pdf',
            },
            {'title': 'Later', 'pdfUrl': 'https://example.org/later.pdf'},
          ],
        },
      ];
      expect(undoImportNodes(tree, 'old'), 1);
      expect(jsonEncode(tree), contains('Later'));
      expect(jsonEncode(tree), isNot(contains('Imported')));
    },
  );
  test(
    'all three website-compatible templates round trip after real links replace placeholders',
    () {
      String real(String text) => text
          .replaceAll('REPLACE_WITH_FILE_ID', 'real-document')
          .replaceAll('VIDEO_ID', 'dQw4w9WgXcQ');
      final csv = validateImport(real(importTemplateCsv()), 'template.csv');
      final json = validateImport(
        real(
          dataFileCsv(
            'template.json',
            Uint8List.fromList(utf8.encode(importTemplateJson())),
          ),
        ),
        'template.json',
      );
      final excel = validateImport(
        real(dataFileCsv('template.xlsx', importTemplateXlsx())),
        'template.xlsx',
      );
      for (final p in [csv, json, excel]) {
        expect(p.errors, isEmpty);
        expect(p.rows.length, 6);
        expect(p.rows.where((r) => r.lecture).single.labels.last, 'ANS');
        expect(p.rows.map((r) => r.storageKey).toSet().length, 5);
      }
    },
  );
  test(
    'grouped nested website JSON inherits year, subject, section, topic and pdfUrl',
    () {
      final source = {
        'notes': [
          {
            'professionalYear': '2nd Professional',
            'semester': 'Semester 1',
            'subject': 'Pharmacology',
            'sections': [
              {
                'name': 'Books',
                'topics': [
                  {
                    'title': 'ANS',
                    'files': [
                      {
                        'title': 'Textbook',
                        'pdfUrl': 'https://example.org/book.pdf',
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      };
      final p = validateImport(
        dataFileCsv(
          'nested.json',
          Uint8List.fromList(utf8.encode(jsonEncode(source))),
        ),
        'nested.json',
      );
      expect(p.errors, isEmpty);
      expect(p.rows.single.title, 'Textbook');
      expect(p.rows.single.labels, [
        '2nd Professional',
        'Semester 1',
        'Pharmacology',
        'Books',
        'ANS',
      ]);
    },
  );
  test(
    'website default type, blank lecture filename, and past-paper routing are retained',
    () {
      final p = validateImport(
        'Professional Year,Semester,Subject,Section,Topic,File Name,Link\n2nd Professional,Semester 1,Pharmacology,Notes,2025,Pharmacology past paper,https://example.org/paper.pdf',
        'legacy.csv',
        defaultType: 'notes',
      );
      expect(p.errors, isEmpty);
      expect(p.rows.single.storageKey, 'pw_pastpapers');
    },
  );
  test('valid rows may be previewed while malformed rows remain excluded', () {
    final p = validateImport(
      '${csvTemplate.split('\r\n').first}\nnotes,Year,Semester,Subject,Notes,Topic,Good,https://example.org/good.pdf,true\nnotes,Year,Semester,Subject,Notes,Topic,Bad,http://example.org/bad.pdf,true',
      'mixed.csv',
    );
    expect(p.rows.length, 1);
    expect(p.errors, isNotEmpty);
    expect(p.valid, true);
  });
  test('undo removes only batch-owned content and preserves later additions', () {
    final tree = <Map<String, dynamic>>[];
    var id = 0;
    final original = validateImport(
      '${csvTemplate.split('\r\n').first}\nnotes,Year,Semester,Subject,Notes,Topic,Imported,https://example.org/imported.pdf,true',
      'import.csv',
    ).rows;
    mergeRows(tree, original, () => '${id++}', batchId: 'batch-one');
    final later = validateImport(
      '${csvTemplate.split('\r\n').first}\nnotes,Year,Semester,Subject,Notes,Topic,Later,https://example.org/later.pdf,true',
      'later.csv',
    ).rows;
    mergeRows(tree, later, () => '${id++}', batchId: 'batch-two');
    expect(undoImportNodes(tree, 'batch-one'), 1);
    expect(tree, isNotEmpty);
    final serialized = jsonEncode(tree);
    expect(serialized, contains('Later'));
    expect(serialized, isNot(contains('Imported')));
    expect(undoImportNodes(tree, 'batch-one'), 0);
  });
}

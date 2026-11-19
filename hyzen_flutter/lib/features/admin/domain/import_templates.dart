import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'import_formats.dart';

const importTemplateRows = <Map<String, String>>[
  {
    'Type': 'Notes',
    'Professional Year': '2nd Professional',
    'Semester': 'Semester 1',
    'Subject': 'Pharmacology',
    'Section': 'Notes',
    'Topic': 'ANS',
    'File Name': 'ANS notes.pdf',
    'Link': 'https://drive.google.com/file/d/REPLACE_WITH_FILE_ID/view',
    'published': 'true',
  },
  {
    'Type': 'Books',
    'Professional Year': '2nd Professional',
    'Semester': 'Semester 1',
    'Subject': 'Pharmacology',
    'Section': 'Books',
    'Topic': 'ANS',
    'File Name': 'ANS textbook.pdf',
    'Link': 'https://drive.google.com/file/d/REPLACE_WITH_FILE_ID/view',
    'published': 'true',
  },
  {
    'Type': 'Special Books',
    'Professional Year': '2nd Professional',
    'Semester': 'Semester 1',
    'Subject': 'Pharmacology',
    'Section': 'Guide Books',
    'Topic': 'ANS',
    'File Name': 'ANS guide.pdf',
    'Link': 'https://drive.google.com/file/d/REPLACE_WITH_FILE_ID/view',
    'published': 'true',
  },
  {
    'Type': 'MCQs',
    'Professional Year': '2nd Professional',
    'Semester': 'Semester 1',
    'Subject': 'Pharmacology',
    'Section': 'Practice',
    'Topic': 'ANS',
    'File Name': 'ANS MCQs.pdf',
    'Link': 'https://drive.google.com/file/d/REPLACE_WITH_FILE_ID/view',
    'published': 'true',
  },
  {
    'Type': 'Past Papers',
    'Professional Year': '2nd Professional',
    'Semester': 'Semester 1',
    'Subject': 'Pharmacology',
    'Section': 'Past Papers',
    'Topic': '2025',
    'File Name': 'Pharmacology past paper.pdf',
    'Link': 'https://drive.google.com/file/d/REPLACE_WITH_FILE_ID/view',
    'published': 'true',
  },
  {
    'Type': 'Lectures',
    'Professional Year': '2nd Professional',
    'Semester': 'Semester 1',
    'Subject': 'Pharmacology',
    'Section': '',
    'Topic': 'ANS',
    'File Name': '',
    'Link': 'https://www.youtube.com/watch?v=VIDEO_ID',
    'published': 'true',
  },
];
String importTemplateCsv() => tableCsv([
  importTemplateRows.first.keys.toList(),
  for (final r in importTemplateRows) r.values.toList(),
]);
String importTemplateJson() =>
    const JsonEncoder.withIndent('  ').convert(importTemplateRows);
Uint8List importTemplateXlsx() {
  final zip = Archive();
  void put(String path, String text) {
    final bytes = utf8.encode(text);
    zip.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  const names = [
    'Notes',
    'Special Books and Notes',
    'MCQs',
    'Past Papers',
    'Lectures',
  ];
  String esc(String s) => XmlText(s).toXmlString();
  put(
    '[Content_Types].xml',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>${[for (var i = 1; i <= 5; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>',
  );
  put(
    '_rels/.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  put(
    'xl/workbook.xml',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${[for (var i = 0; i < 5; i++) '<sheet name="${names[i]}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets></workbook>',
  );
  put(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${[for (var i = 1; i <= 5; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}</Relationships>',
  );
  for (var i = 0; i < 5; i++) {
    final rows = importTemplateRows
        .where(
          (r) => switch (i) {
            0 => r['Type'] == 'Notes' || r['Type'] == 'Books',
            1 => r['Type'] == 'Special Books',
            2 => r['Type'] == 'MCQs',
            3 => r['Type'] == 'Past Papers',
            _ => r['Type'] == 'Lectures',
          },
        )
        .toList();
    final table = [
      importTemplateRows.first.keys.toList(),
      for (final row in rows) row.values.toList(),
    ];
    put(
      'xl/worksheets/sheet${i + 1}.xml',
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${[
        for (var y = 0; y < table.length; y++) '<row r="${y + 1}">${[for (var x = 0; x < table[y].length; x++) '<c r="${String.fromCharCode(65 + x)}${y + 1}" t="inlineStr"><is><t xml:space="preserve">${esc(table[y][x])}</t></is></c>'].join()}</row>',
      ].join()}</sheetData></worksheet>',
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(zip)!);
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../../../core/errors/app_error.dart';
import 'import_csv.dart';

String csvCell(Object? value) => '"${'${value ?? ''}'.replaceAll('"', '""')}"';
String tableCsv(List<List<Object?>> rows) =>
    rows.map((r) => r.map(csvCell).join(',')).join('\r\n');
String dataFileCsv(String name, Uint8List bytes) {
  final ext = name.toLowerCase().split('.').last;
  if (ext == 'csv') return utf8.decode(bytes);
  if (ext == 'json') {
    final decoded = jsonDecode(
      utf8.decode(bytes).replaceFirst(RegExp(r'^\uFEFF'), ''),
    );
    final maps = resourceJsonRows(decoded);
    if (maps.isEmpty) {
      throw FriendlyException(
        'No resource rows found. Use Data Manager for full backups.',
      );
    }
    final headers = <String>{for (final row in maps) ...row.keys}.toList();
    return tableCsv([
      headers,
      for (final row in maps) [for (final key in headers) row[key]],
    ]);
  }
  if (ext != 'xlsx') {
    throw FriendlyException(
      'Choose CSV, JSON or XLSX. Save older XLS files as CSV first.',
    );
  }
  final zip = ZipDecoder().decodeBytes(bytes, verify: true);
  var total = 0;
  for (final f in zip) {
    total += f.size;
    if (total > 32 * 1024 * 1024) {
      throw FriendlyException('Workbook is too large after decompression.');
    }
  }
  XmlDocument? document(String path) {
    final files = zip.files.where((f) => f.name == path);
    if (files.isEmpty) return null;
    return XmlDocument.parse(utf8.decode(files.first.content as List<int>));
  }

  final shared = <String>[];
  for (final si
      in document('xl/sharedStrings.xml')?.findAllElements('si') ??
          <XmlElement>[]) {
    shared.add(si.findAllElements('t').map((t) => t.innerText).join());
  }
  final sheet =
      zip.files
          .where(
            (f) => RegExp(r'^xl/worksheets/sheet[0-9]+\.xml$').hasMatch(f.name),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  if (sheet.isEmpty) {
    throw FriendlyException('Workbook has no readable worksheets.');
  }
  final sheetNames = <String, String>{};
  final rels = {
    for (final rel
        in document(
              'xl/_rels/workbook.xml.rels',
            )?.findAllElements('Relationship') ??
            <XmlElement>[])
      rel.getAttribute('Id'): rel.getAttribute('Target'),
  };
  for (final sh
      in document('xl/workbook.xml')?.findAllElements('sheet') ??
          <XmlElement>[]) {
    final rid = sh.attributes
        .where((a) => a.name.local == 'id')
        .firstOrNull
        ?.value;
    final target = rels[rid];
    if (target != null) {
      sheetNames[target.startsWith('/') ? target.substring(1) : 'xl/$target'] =
          sh.getAttribute('name') ?? '';
    }
  }
  final result = <List<Object?>>[];
  final mergedHeaders = <String>[];
  final mergedRows = <Map<String, Object?>>[];
  for (final file in sheet) {
    final rows = <List<Object?>>[];
    final doc = document(file.name)!;
    for (final row in doc.findAllElements('row')) {
      final columns = <int, String>{};
      for (final cell in row.findElements('c')) {
        final letters =
            RegExp(
              r'^[A-Z]+',
            ).firstMatch(cell.getAttribute('r') ?? '')?.group(0) ??
            'A';
        var column = 0;
        for (final unit in letters.codeUnits) {
          column = column * 26 + unit - 64;
        }
        column--;
        if (column > 80) {
          throw FriendlyException('Workbook has too many columns.');
        }
        final raw = cell.getElement('v')?.innerText ?? '';
        final type = cell.getAttribute('t');
        final value = type == 's'
            ? (int.tryParse(raw) != null &&
                      int.parse(raw) >= 0 &&
                      int.parse(raw) < shared.length
                  ? shared[int.parse(raw)]
                  : '')
            : type == 'inlineStr'
            ? cell.findAllElements('t').map((e) => e.innerText).join()
            : raw;
        columns[column] = value;
      }
      if (columns.isEmpty) continue;
      final max = columns.keys.reduce((a, b) => a > b ? a : b);
      rows.add([for (var i = 0; i <= max; i++) columns[i] ?? '']);
      if (rows.length > 2001) {
        throw FriendlyException('Import at most 2,000 rows at a time.');
      }
    }
    if (rows.isEmpty) continue;
    final headings = rows.first.map((e) => '$e').toList();
    final keys = headings.map(canonicalHeader).toList();
    if (keys.toSet().length != keys.length) {
      throw FriendlyException(
        'Repeated columns in ${sheetNames[file.name] ?? file.name}.',
      );
    }
    for (var i = 0; i < keys.length; i++) {
      if (!mergedHeaders.any((h) => canonicalHeader(h) == keys[i])) {
        mergedHeaders.add(headings[i]);
      }
    }
    final inferred = importResourceType(sheetNames[file.name] ?? '');
    if (inferred != null &&
        !mergedHeaders.any((h) => canonicalHeader(h) == 'kind')) {
      mergedHeaders.add('kind');
    }
    for (final row in rows.skip(1)) {
      final item = <String, Object?>{
        for (var i = 0; i < keys.length; i++)
          keys[i]: i < row.length ? row[i] : '',
      };
      if (inferred != null &&
          (item['kind'] == null || '${item['kind']}'.isEmpty)) {
        item['kind'] = inferred;
      }
      mergedRows.add(item);
    }
    if (mergedRows.length > 2000) {
      throw FriendlyException('Import at most 2,000 rows at a time.');
    }
  }
  result.add(mergedHeaders);
  for (final row in mergedRows) {
    result.add([for (final h in mergedHeaders) row[canonicalHeader(h)] ?? '']);
  }
  return tableCsv(result);
}

List<Map<String, dynamic>> resourceJsonRows(
  Object? data, [
  Map<String, String> inherited = const {},
]) {
  if (data is List) {
    return [for (final item in data) ...resourceJsonRows(item, inherited)];
  }
  if (data is! Map) return [];
  final map = Map<String, dynamic>.from(data);
  if (map['rows'] is List) return resourceJsonRows(map['rows'], inherited);
  final groups = {
    'notes': 'notes',
    'mcqs': 'mcqs',
    'special': 'special',
    'papers': 'papers',
    'pastPapers': 'papers',
    'pastpapers': 'papers',
    'lectures': 'lectures',
  };
  final grouped = [
    for (final e in groups.entries)
      if (map[e.key] is List)
        ...resourceJsonRows(map[e.key], {...inherited, 'kind': e.value}),
  ];
  if (grouped.isNotEmpty) return grouped;
  final canonical = <String, String>{...inherited};
  for (final e in map.entries) {
    if (e.value is! List && e.value is! Map && e.value != null) {
      final key = canonicalHeader(e.key);
      if ('${e.value}'.trim().isNotEmpty) canonical[key] = '${e.value}';
    }
  }
  for (final spec in const [
    ('semesters', 'professional_year'),
    ('subjects', 'semester'),
    ('sections', 'subject'),
    ('topics', 'section'),
    ('files', 'topic'),
  ]) {
    if (map[spec.$1] is List && (canonical[spec.$2] ?? '').isEmpty) {
      canonical[spec.$2] =
          '${map['label'] ?? map['title'] ?? map['name'] ?? ''}';
    }
  }
  for (final spec in const [
    ('semesters', 'semester'),
    ('subjects', 'subject'),
    ('sections', 'section'),
    ('topics', 'topic'),
    ('files', 'title'),
  ]) {
    final children = map[spec.$1];
    if (children is List) {
      return [
        for (final child in children)
          if (child is Map)
            ...resourceJsonRows({
              ...Map<String, dynamic>.from(child),
              if (spec.$2 != 'title')
                spec.$2:
                    child[spec.$2] ??
                    child['label'] ??
                    child['title'] ??
                    child['name'] ??
                    '',
            }, canonical),
      ];
    }
  }
  return [canonical];
}

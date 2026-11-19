import 'dart:convert';

import '../../../core/errors/app_error.dart';
import '../../academics/domain/drive.dart';
import '../../academics/domain/models.dart';

const csvTemplate =
    'kind,professional_year,semester,subject,section,topic,title,url,published\r\n'
    'notes,2nd Professional,Semester 1,Pharmacology,Notes,Diabetes,Diabetes Notes,https://drive.google.com/file/d/REPLACE_WITH_FILE_ID/view,true\r\n';

class ImportRow {
  const ImportRow({
    required this.kind,
    required this.labels,
    required this.title,
    required this.url,
    required this.published,
    required this.source,
    required this.line,
    this.lecture = false,
  });
  final LibraryKind kind;
  final bool lecture;
  String get storageKey => lecture ? 'pw_lectures_tree' : kind.storageKey;
  final List<String> labels;
  final String title, url, source;
  final bool published;
  final int line;
}

class ImportPreview {
  const ImportPreview(this.rows, this.errors);
  final List<ImportRow> rows;
  final List<String> errors;
  bool get valid => rows.isNotEmpty;
}

/// RFC-4180-style parser: commas, escaped quotes, embedded line breaks and BOM.
List<List<String>> parseCsv(String input) {
  final text = input.replaceFirst(RegExp(r'^\uFEFF'), '');
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false, afterQuote = false;
  void cell() {
    row.add(field.toString());
    field = StringBuffer();
    afterQuote = false;
  }

  void endRow() {
    cell();
    if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
    row = [];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          afterQuote = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == ',') {
      cell();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else if (c == '"') {
      if (field.isNotEmpty || afterQuote) {
        throw FriendlyException(
          'Unexpected quote in CSV. Put quoted fields inside double quotes.',
        );
      }
      quoted = true;
    } else {
      if (afterQuote && c.trim().isNotEmpty) {
        throw FriendlyException('Unexpected text after a quoted CSV field.');
      }
      if (!afterQuote) field.write(c);
    }
  }
  if (quoted) throw FriendlyException('CSV has an unclosed quoted field.');
  if (field.isNotEmpty || row.isNotEmpty || afterQuote) endRow();
  return rows;
}

ImportPreview validateImport(
  String text,
  String source, {
  String defaultType = 'auto',
}) {
  final errors = <String>[];
  final out = <ImportRow>[];
  List<List<String>> csv;
  try {
    csv = parseCsv(text);
  } on FriendlyException catch (e) {
    return ImportPreview([], ['$source: ${e.message}']);
  }
  if (csv.isEmpty) return ImportPreview([], ['$source: CSV is empty.']);
  if (csv.length > 2001) {
    return ImportPreview([], ['$source: Import at most 2,000 rows at a time.']);
  }
  final headers = csv.first.map(canonicalHeader).toList();
  const required = [
    'kind',
    'professional_year',
    'semester',
    'subject',
    'section',
    'topic',
    'title',
    'url',
  ];
  if (headers.toSet().length != headers.length) {
    errors.add('$source: Repeated column names.');
  }
  for (final key in ['professional_year', 'semester', 'subject', 'url']) {
    if (!headers.contains(key)) errors.add('$source: Missing column $key.');
  }
  if (errors.isNotEmpty) return ImportPreview([], errors);
  for (var i = 1; i < csv.length; i++) {
    final row = csv[i];
    final origin = '$source row ${i + 1}';
    if (row.length != headers.length) {
      errors.add(
        '$origin: Expected ${headers.length} columns, found ${row.length}.',
      );
      continue;
    }
    final values = {
      for (var j = 0; j < headers.length; j++) headers[j]: row[j].trim(),
    };
    for (final key in required) {
      values.putIfAbsent(key, () => '');
    }
    final type = values['kind']!.isEmpty
        ? defaultType
        : values['kind']!.toLowerCase();
    var normalizedType = importResourceType(type);
    final signal = [
      values['title'],
      values['section'],
      values['topic'],
    ].join(' ');
    if (normalizedType != 'lectures' &&
        normalizedType != 'mcqs' &&
        RegExp(
          r'\bpast\s*-?\s*papers?\b|\bpastpaers?\b|\bquestion\s*-?\s*papers?\b',
          caseSensitive: false,
        ).hasMatch(signal)) {
      normalizedType = 'papers';
    }
    if (type == 'auto' || type.isEmpty) {
      normalizedType ??= importResourceType(values['section'] ?? '');
    }
    final lecture = normalizedType == 'lectures';
    final kind = lecture
        ? LibraryKind.notes
        : LibraryKindX.parse(normalizedType ?? '');
    if (values['section']!.isEmpty) {
      final token = type.replaceAll(RegExp(r'[^a-z]'), '');
      values['section'] = switch (token) {
        'book' || 'books' || 'textbook' || 'textbooks' => 'Books',
        'slide' ||
        'slides' ||
        'ppt' ||
        'presentation' ||
        'presentations' => 'Slides',
        'specialbooks' || 'specialbook' => 'Special Books',
        'guidenotes' ||
        'guidebooks' ||
        'studyguide' ||
        'studyguides' => 'Guide Notes',
        'generalnotes' || 'special' || 'specialnotes' => 'General Notes',
        _ => '',
      };
    }
    final labels = [for (final key in required.sublist(1, 6)) values[key]!];
    if (lecture) {
      if (labels[3].isEmpty) labels[3] = 'Lectures';
      if (labels[4].isEmpty) labels[4] = values['title']!;
      if (values['title']!.isEmpty) values['title'] = labels[4];
    }
    final title = values['title']!, url = values['url']!;
    final uri = Uri.tryParse(url);
    final published = (values['published'] ?? 'true').toLowerCase();
    final before = errors.length;
    if (kind == null) {
      errors.add(
        '$origin: kind must be notes, mcqs, special, papers or lectures.',
      );
    }
    if ([...labels, title].any((v) => v.isEmpty || v.length > 180)) {
      errors.add(
        '$origin: Names and title are required and must be 180 characters or fewer.',
      );
    }
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        url.length > 2000) {
      errors.add('$origin: Provide a complete HTTPS file URL.');
    }
    if (RegExp(r'REPLACE_WITH_FILE_ID|/FILE_ID|=VIDEO_ID').hasMatch(url)) {
      errors.add('$origin: Replace the example file link with your real link.');
    }
    if (lecture &&
        uri != null &&
        !(uri.host == 'youtu.be' ||
            uri.host == 'youtube.com' ||
            uri.host.endsWith('.youtube.com') ||
            uri.host == 'youtube-nocookie.com' ||
            uri.host.endsWith('.youtube-nocookie.com'))) {
      errors.add('$origin: Lectures need a YouTube link.');
    }
    if (!['true', 'false', '1', '0', ''].contains(published)) {
      errors.add('$origin: published must be true or false.');
    }
    if (errors.length == before) {
      out.add(
        ImportRow(
          kind: kind!,
          lecture: lecture,
          labels: labels,
          title: title,
          url: url,
          published: published != 'false' && published != '0',
          source: source,
          line: i + 1,
        ),
      );
    }
  }
  if (out.length > 2000) {
    errors.add('$source: Import at most 2,000 rows at a time.');
  }
  if (csv.length == 1) errors.add('$source: No data rows found.');
  return ImportPreview(out, errors);
}

List<Map<String, dynamic>> copyTree(Object? raw, LibraryKind kind) {
  final copy = raw == null ? <dynamic>[] : jsonDecode(jsonEncode(raw));
  return kind == LibraryKind.papers
      ? normalizePastPapers(copy)
      : ensureNestedTree(copy, kind);
}

const childKeys = ['semesters', 'subjects', 'sections', 'topics', 'files'];
String labelKey(int depth) => depth < 3 ? 'label' : 'title';
List<Map<String, dynamic>> childrenAt(
  List<Map<String, dynamic>> tree,
  List<String> path,
) {
  var list = tree;
  for (var i = 0; i < path.length; i++) {
    final node = list.where((m) => '${m['id']}' == path[i]).firstOrNull;
    if (node == null || i >= childKeys.length) {
      throw FriendlyException('This item changed. Refresh and try again.');
    }
    final key = childKeys[i];
    final children = node[key];
    final next = children is List
        ? children
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList()
        : <Map<String, dynamic>>[];
    node[key] = next;
    list = next;
  }
  return list;
}

class MergeResult {
  const MergeResult(this.added, this.skipped, [this.conflicts = const []]);
  final int added, skipped;
  final List<String> conflicts;
}

MergeResult mergeRows(
  List<Map<String, dynamic>> tree,
  Iterable<ImportRow> rows,
  String Function() newId, {
  String? batchId,
}) {
  var added = 0, skipped = 0;
  for (final row in rows) {
    var list = tree;
    for (var depth = 0; depth < row.labels.length; depth++) {
      final key = labelKey(depth);
      var node = list
          .where(
            (m) =>
                '${m[key] ?? ''}'.trim().toLowerCase() ==
                row.labels[depth].toLowerCase(),
          )
          .firstOrNull;
      if (node == null) {
        node = {
          'id': newId(),
          if (batchId != null) 'importBatchId': batchId,
          key: row.labels[depth],
          'order': list.length + 1,
          'published': true,
          childKeys[depth]: <Map<String, dynamic>>[],
        };
        list.add(node);
      }
      final children = node[childKeys[depth]];
      list = children is List
          ? children
                .whereType<Map>()
                .map((m) => m.cast<String, dynamic>())
                .toList()
          : <Map<String, dynamic>>[];
      node[childKeys[depth]] = list;
    }
    if (list.any(
      (m) =>
          DriveLinks.offlineKey('${m['pdfUrl'] ?? ''}') ==
          DriveLinks.offlineKey(row.url),
    )) {
      skipped++;
      continue;
    }
    list.add({
      'id': newId(),
      if (batchId != null) 'importBatchId': batchId,
      'title': row.title,
      'pdfUrl': row.url,
      'published': row.published,
      'order': list.length + 1,
      'downloads': 0,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    added++;
  }
  return MergeResult(added, skipped);
}

String canonicalHeader(String value) {
  final key = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return switch (key) {
    'kind' || 'type' || 'resourcetype' || 'materialtype' => 'kind',
    'professionalyear' ||
    'professional' ||
    'prof' ||
    'profyear' ||
    'year' ||
    'class' => 'professional_year',
    'semester' || 'sem' || 'term' => 'semester',
    'subject' || 'subjectname' => 'subject',
    'section' ||
    'sectionname' ||
    'subsection' ||
    'subsectionname' ||
    'category' ||
    'group' => 'section',
    'topic' || 'topicname' => 'topic',
    'filename' ||
    'file' ||
    'filetitle' ||
    'documentname' ||
    'name' ||
    'title' => 'title',
    'url' ||
    'link' ||
    'filelink' ||
    'drivelink' ||
    'pdflink' ||
    'pdfurl' ||
    'youtubeurl' ||
    'youtubelink' ||
    'videolink' => 'url',
    _ => value.trim().toLowerCase().replaceAll(' ', '_'),
  };
}

MergeResult mergeLectureRows(
  List<Map<String, dynamic>> tree,
  Iterable<ImportRow> rows,
  String Function() id, {
  String? batchId,
}) {
  var added = 0, skipped = 0;
  final conflicts = <String>[];
  for (final row in rows) {
    var list = tree;
    for (var depth = 0; depth < 3; depth++) {
      var node = list
          .where(
            (m) =>
                '${m['label']}'.toLowerCase() ==
                row.labels[depth].toLowerCase(),
          )
          .firstOrNull;
      final child = ['semesters', 'subjects', 'topics'][depth];
      if (node == null) {
        node = {
          'id': id(),
          if (batchId != null) 'importBatchId': batchId,
          'label': row.labels[depth],
          'order': list.length + 1,
          'published': true,
          child: <Map<String, dynamic>>[],
        };
        list.add(node);
      }
      final next = (node[child] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      node[child] = next;
      list = next;
    }
    if (list.any(
      (m) =>
          m['youtubeUrl'] == row.url ||
          m['playlistUrl'] == row.url ||
          m['externalUrl'] == row.url,
    )) {
      skipped++;
      continue;
    }
    if (list.any(
      (m) =>
          '${m['title'] ?? ''}'.trim().toLowerCase() ==
          row.title.trim().toLowerCase(),
    )) {
      conflicts.add(
        '${row.source} row ${row.line}: ${row.title} already has a different lecture link.',
      );
      continue;
    }
    final host = Uri.parse(row.url).host;
    final key = host.contains('youtube.com') || host == 'youtu.be'
        ? (Uri.parse(row.url).queryParameters.containsKey('list')
              ? 'playlistUrl'
              : 'youtubeUrl')
        : 'externalUrl';
    list.add({
      'id': id(),
      if (batchId != null) 'importBatchId': batchId,
      'title': row.title,
      'published': row.published,
      key: row.url,
      'order': list.length + 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    added++;
  }
  return MergeResult(added, skipped, conflicts);
}

String? importResourceType(String value) {
  final t = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if ([
    'special',
    'specialbook',
    'specialbooks',
    'specialbooksnotes',
    'specialnotes',
    'guidenote',
    'guidenotes',
    'guidebook',
    'guidebooks',
    'generalnote',
    'generalnotes',
    'studyguide',
    'studyguides',
  ].contains(t)) {
    return 'special';
  }
  if ([
    'note',
    'notes',
    'notespdf',
    'book',
    'books',
    'textbook',
    'textbooks',
    'slide',
    'slides',
    'ppt',
    'presentation',
    'presentations',
    'assignment',
    'assignments',
    'practical',
    'practicals',
    'reference',
    'referencematerial',
    'handout',
    'handouts',
    'handwrittennotes',
  ].contains(t)) {
    return 'notes';
  }
  if ([
    'mcq',
    'mcqs',
    'multiplechoice',
    'multiplechoicequestions',
  ].contains(t)) {
    return 'mcqs';
  }
  if ([
    'paper',
    'papers',
    'pastpaper',
    'pastpapers',
    'pastpaer',
    'pastpaers',
  ].contains(t)) {
    return 'papers';
  }
  if ([
    'lecture',
    'lectures',
    'video',
    'videos',
    'youtube',
    'youtubelecture',
  ].contains(t)) {
    return 'lectures';
  }
  return null;
}

int undoImportNodes(List<Map<String, dynamic>> tree, String batchId) {
  var removed = 0;
  tree.removeWhere((node) {
    var hasChildren = false;
    for (final key in childKeys) {
      final raw = node[key];
      if (raw is List) {
        final children = raw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        removed += undoImportNodes(children, batchId);
        node[key] = children;
        hasChildren |= children.isNotEmpty;
      }
    }
    final owner =
        node['importBatchId'] ??
        node['_importBatch'] ??
        node['_createdByBatch'];
    if (owner != batchId || hasChildren) return false;
    if (node.containsKey('pdfUrl') ||
        node.containsKey('url') ||
        node.containsKey('youtubeUrl') ||
        node.containsKey('playlistUrl') ||
        node.containsKey('externalUrl')) {
      removed++;
    }
    return true;
  });
  return removed;
}

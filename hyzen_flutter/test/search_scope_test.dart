import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/search/data/search_index.dart';
import 'package:hyzen_pharmd/features/search/data/search_scope.dart';
import 'package:hyzen_pharmd/features/academics/domain/models.dart';
import 'package:hyzen_pharmd/features/downloads/domain/download_record.dart';

void main() {
  final index = [
    SearchHit(
      type: HitType.file,
      title: 'Renal notes',
      subtitle: '',
      route: '/study/notes',
      kind: LibraryKind.notes,
      url: 'https://example.org/notes.pdf',
    ),
    SearchHit(
      type: HitType.file,
      title: 'Renal guide book',
      subtitle: '',
      route: '/study/special',
      kind: LibraryKind.special,
    ),
    SearchHit(
      type: HitType.lecture,
      title: 'Renal lecture',
      subtitle: '',
      route: '/lectures',
    ),
  ];
  final downloads = [
    DownloadRecord(
      key: 'ready',
      kind: LibraryKind.notes,
      title: 'Renal offline',
      sourceUrl: 'https://example.org/offline.pdf',
      status: DownloadStatus.ready,
      localPath: '/fixture.pdf',
    ),
    DownloadRecord(
      key: 'paused',
      kind: LibraryKind.notes,
      title: 'Renal partial',
      sourceUrl: 'https://example.org/partial.pdf',
      status: DownloadStatus.paused,
    ),
  ];
  for (final pair in [
    (SearchScope.notes, 'Renal notes'),
    (SearchScope.books, 'Renal guide book'),
    (SearchScope.lectures, 'Renal lecture'),
    (SearchScope.downloads, 'Renal offline'),
  ]) {
    test('${pair.$1.name} searches only its category', () {
      final hits = runSearch(scopedIndex(index, downloads, pair.$1), 'renal');
      expect(hits.map((h) => h.title), [pair.$2]);
    });
  }
  test(
    'all includes available offline files and excludes incomplete transfers',
    () {
      expect(
        runSearch(scopedIndex(index, downloads, SearchScope.all), 'renal'),
        hasLength(4),
      );
      expect(
        runSearch(scopedIndex(index, downloads, SearchScope.all), 'partial'),
        isEmpty,
      );
    },
  );
}

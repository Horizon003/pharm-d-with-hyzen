import '../../academics/domain/models.dart';
import '../../downloads/domain/download_record.dart';
import 'search_index.dart';

enum SearchScope { all, notes, books, lectures, downloads }

extension SearchScopeLabel on SearchScope {
  String get label => switch (this) {
    SearchScope.all => 'All',
    SearchScope.notes => 'Notes',
    SearchScope.books => 'Books',
    SearchScope.lectures => 'Lectures',
    SearchScope.downloads => 'Downloads',
  };
}

List<SearchHit> scopedIndex(
  List<SearchHit> index,
  Iterable<DownloadRecord> downloads,
  SearchScope scope,
) {
  final saved = [
    for (final d in downloads)
      if (d.isAvailableOffline)
        SearchHit(
          type: HitType.file,
          title: d.title,
          subtitle: 'Downloaded · ${d.subtitle}',
          route: '/downloads',
          kind: d.kind,
          url: d.sourceUrl,
          trail: d.trail,
        ),
  ];
  final remoteUrls = index.map((h) => h.url).whereType<String>().toSet();
  return switch (scope) {
    SearchScope.all => [
      ...index,
      ...saved.where((d) => !remoteUrls.contains(d.url)),
    ],
    SearchScope.notes =>
      index.where((h) => h.kind == LibraryKind.notes).toList(),
    SearchScope.books =>
      index.where((h) => h.kind == LibraryKind.special).toList(),
    SearchScope.lectures =>
      index.where((h) => h.type == HitType.lecture).toList(),
    SearchScope.downloads => saved,
  };
}

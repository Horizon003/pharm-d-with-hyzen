import '../../downloads/data/downloads_controller.dart';
import '../data/search_scope.dart';
import 'home_search.dart';
import 'package:flutter/material.dart';
import '../../../app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/links.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/hyzen_art.dart';
import '../../academics/presentation/discovery_widgets.dart';
import '../../academics/presentation/library_screens.dart';
import '../../academics/domain/models.dart';
import '../../content/data/content_providers.dart';
import '../../content/data/content_source.dart';
import '../../downloads/domain/download_record.dart';
import '../../shell/app_shell.dart';
import '../data/search_index.dart';
import '../data/ocr_index.dart';
import '../../../app/safe_nav.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.focusSearch = false,
    this.initialQuery = '',
    this.initialScope = SearchScope.all,
  });
  final bool focusSearch;
  final String initialQuery;
  final SearchScope initialScope;
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late String _q = widget.initialQuery;
  late SearchScope _scope = widget.initialScope;
  HitType? _only;

  static const _filters = <(HitType?, String)>[
    (null, 'All'),
    (HitType.file, 'Files'),
    (HitType.subject, 'Subjects'),
    (HitType.topic, 'Topics'),
    (HitType.lecture, 'Lectures'),
    (HitType.product, 'Shop'),
    (HitType.blog, 'Blog'),
  ];

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialScope != widget.initialScope) {
      _q = widget.initialQuery;
      _scope = widget.initialScope;
      _only = null;
    }
  }

  IconData _icon(HitType t) => switch (t) {
    HitType.subject => Icons.science_rounded,
    HitType.section => Icons.folder_copy_rounded,
    HitType.topic => Icons.topic_rounded,
    HitType.file => Icons.picture_as_pdf_rounded,
    HitType.lecture => Icons.play_circle_rounded,
    HitType.product => Icons.shopping_bag_rounded,
    HitType.blog => Icons.article_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final session =
        '${ref.watch(sessionRevisionProvider)}:${ref.watch(searchRevisionProvider)}';
    ref.listen(sessionRevisionProvider, (_, __) {
      setState(() {
        _q = '';
        _only = null;
      });
    });
    ref.listen(searchRevisionProvider, (_, __) {
      setState(() {
        _q = '';
        _only = null;
      });
    });
    final index = ref.watch(searchIndexProvider);
    ref.watch(ocrIndexProvider);
    final hits = [
      ...runSearch(
        scopedIndex(index, ref.watch(downloadsProvider).values, _scope),
        _q,
        only: _only,
      ),
      if (_scope == SearchScope.all &&
          _q.trim().isNotEmpty &&
          (_only == null || _only == HitType.file))
        for (final result in ref.read(ocrIndexProvider.notifier).search(_q))
          SearchHit(
            type: HitType.file,
            title: result.documentName,
            subtitle: 'Page ${result.page} · OCR · ${result.snippet}',
            route: '/pdf-studio/viewer/${result.documentId}',
            studioFileId: result.documentId,
            page: result.page,
          ),
    ];
    final settings = ref.watch(siteSettingsProvider);
    final keys = [
      for (final k in LibraryKind.values)
        if (settings.sectionEnabled(k.sectionId)) k.storageKey,
      if (settings.sectionEnabled('lectures')) 'pw_lectures_tree',
      if (settings.sectionEnabled('blog')) 'pw_blogs',
      if (settings.sectionEnabled('shop') && !settings.shopComingSoon)
        'pw_products',
    ];
    final sources = keys.map((k) => ref.watch(contentProvider(k))).toList();
    final loading = sources.any((s) => s.isLoading && !s.hasValue);
    final failed = sources.any((s) => s.hasError && !s.hasValue);
    return TabPage(
      title: 'Search',
      subtitle: 'Find notes, topics and files',
      onRefresh: () => refreshContent(ref, keys),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HSearchField(
                  key: ValueKey('$session:${widget.initialQuery}'),
                  hint: 'Notes, books, lectures, downloads…',
                  initial: widget.initialQuery,
                  autofocus: widget.focusSearch,
                  onChanged: (v) => setState(() => _q = v),
                ),
                const Gap(HSpace.sm),
                if (_q.isNotEmpty)
                  SearchScopePills(
                    value: _scope,
                    onChanged: (scope) => setState(() {
                      _scope = scope;
                      _only = null;
                    }),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<int>(
                    tooltip: 'More search filters',
                    onSelected: (index) =>
                        setState(() => _only = _filters[index].$1),
                    itemBuilder: (_) => [
                      for (var i = 0; i < _filters.length; i++)
                        PopupMenuItem(value: i, child: Text(_filters[i].$2)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _only == null
                                ? 'More filters'
                                : _filters.firstWhere((f) => f.$1 == _only).$2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(HSpace.md),
              ],
            ),
          ),
        ),
        if (_q.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: HSpace.screen),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HyzenBanner(
                    eyebrow: 'Search smarter',
                    title: 'Find exactly\nwhat you need',
                    subtitle:
                        'Search across notes, MCQs, past papers and more.',
                    art: 'search',
                  ),
                  Gap(20),
                  SectionHeader(title: 'Browse categories'),
                  Gap(10),
                  LibraryShortcuts(),
                  Gap(22),
                  SubjectDiscovery(),
                ],
              ),
            ),
          )
        else if (hits.isEmpty && loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(HSpace.screen),
              child: SkeletonList(),
            ),
          )
        else if (hits.isEmpty && failed)
          SliverToBoxAdapter(
            child: ErrorState(
              message:
                  'Some resources could not load. Connect and refresh to search them.',
              onRetry: () => refreshContent(ref, keys),
            ),
          )
        else if (hits.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results',
              message: 'Try fewer or different words.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
            sliver: SliverList.builder(
              itemCount: hits.length,
              itemBuilder: (c, i) {
                final h = hits[i];
                final color = h.kind != null
                    ? kindColor(h.kind!)
                    : (h.type == HitType.lecture
                          ? HColors.lectures
                          : HColors.primary);
                return ResourceTile(
                  icon: _icon(h.type),
                  color: color,
                  eyebrow: h.type.name,
                  title: h.title,
                  subtitle: h.subtitle,
                  onTap: () {
                    if (h.studioFileId != null) {
                      final page = h.page;
                      c.push(
                        '/pdf-studio/viewer/${h.studioFileId}'
                        '${page != null ? '?page=$page' : ''}',
                      );
                    } else if (h.type == HitType.file &&
                        h.url != null &&
                        h.kind != null) {
                      c.push(
                        '/viewer',
                        extra: FileRef(
                          kind: h.kind!,
                          title: h.title,
                          url: h.url!,
                          trail: h.trail,
                        ),
                      );
                    } else if (h.type == HitType.lecture && h.url != null) {
                      openLink(c, h.url!);
                    } else {
                      c.open(h.route);
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

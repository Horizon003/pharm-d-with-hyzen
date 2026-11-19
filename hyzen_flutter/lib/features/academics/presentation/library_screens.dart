import 'package:flutter/material.dart';
import '../../../core/widgets/workspace_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../app/providers.dart';
import '../../auth/domain/reference_data.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/hyzen_art.dart';
import '../../content/data/content_providers.dart';
import '../../downloads/data/downloads_controller.dart';
import '../../downloads/domain/download_record.dart';
import '../../shell/app_shell.dart';
import '../domain/models.dart';
import '../../../app/safe_nav.dart';

Color kindColor(LibraryKind k) => switch (k) {
  LibraryKind.notes => HColors.notes,
  LibraryKind.mcqs => HColors.mcqs,
  LibraryKind.papers => HColors.papers,
  LibraryKind.special => HColors.special,
};

IconData kindIcon(LibraryKind k) => switch (k) {
  LibraryKind.notes => Icons.menu_book_rounded,
  LibraryKind.mcqs => Icons.quiz_rounded,
  LibraryKind.papers => Icons.history_edu_rounded,
  LibraryKind.special => Icons.auto_stories_rounded,
};

/// Study tab: all libraries (only enabled sections, CONFIRMED sectionEnabled).
class StudyHubScreen extends ConsumerWidget {
  const StudyHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kinds = LibraryKind.values
        .where((k) => ref.watch(sectionEnabledProvider(k.sectionId)))
        .toList();
    final lectures = ref.watch(sectionEnabledProvider('lectures'));
    return TabPage(
      title: 'Study',
      subtitle: ReferenceData.yearLabel(ref.watch(professionalYearProvider)),
      onRefresh: () => refreshContent(ref, [
        'pw_settings',
        ...LibraryKind.values.map((k) => k.storageKey),
        'pw_lectures_tree',
      ]),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
          sliver: SliverList.list(
            children: [
              if (kinds.isNotEmpty) ...[
                HyzenBanner(
                  title: "Today's study",
                  subtitle: 'Notes, MCQs & past papers',
                  art: 'study-kit',
                  eyebrow: ReferenceData.yearLabel(
                    ref.watch(professionalYearProvider),
                  ),
                  actionLabel: 'Open library',
                  action: () => context.push('/study/${kinds.first.name}'),
                ),
                const Gap(18),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your libraries',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.open('/profile/edit'),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: const Text('Change year'),
                  ),
                ],
              ),
              const Gap(8),
              for (final k in kinds) _LibraryCard(kind: k),
              if (lectures)
                ResourceTile(
                  icon: Icons.play_circle_rounded,
                  color: HColors.lectures,
                  eyebrow: 'Video',
                  title: 'Lectures',
                  subtitle: 'Curated video lectures',
                  onTap: () => context.push('/lectures'),
                ),
              if (kinds.isEmpty && !lectures)
                const EmptyState(
                  icon: Icons.lock_clock_rounded,
                  title: 'Libraries are closed',
                  message: 'The admin has temporarily hidden all libraries.',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryCard extends ConsumerWidget {
  const _LibraryCard({required this.kind});
  final LibraryKind kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider(kind));
    final n = lib.valueOrNull?.data.fileCount;
    return ResourceTile(
      icon: kindIcon(kind),
      leading: WorkspaceIcon(switch (kind) {
        LibraryKind.notes => WorkspaceGlyph.notes,
        LibraryKind.papers => WorkspaceGlyph.papers,
        LibraryKind.special => WorkspaceGlyph.books,
        LibraryKind.mcqs => WorkspaceGlyph.mcqs,
      }, size: 42),
      surfaceColor: switch (kind) {
        LibraryKind.notes => const Color(0xFFE8DFF8),
        LibraryKind.papers => const Color(0xFFFFE5CB),
        LibraryKind.special => const Color(0xFFDDEEE2),
        LibraryKind.mcqs => const Color(0xFFDCE8FF),
      },
      color: kindColor(kind),
      eyebrow: n == null
          ? (lib.isLoading ? 'Loading\u2026' : 'Library')
          : '$n files',
      title: kind.title,
      subtitle: kind.blurb,
      onTap: () => context.push('/study/${kind.name}'),
    );
  }
}

/// One reusable drill-down screen for every level of every library.
/// path = [yearId, semesterId, subjectId, sectionId, topicId]
class LibraryLevelScreen extends ConsumerStatefulWidget {
  const LibraryLevelScreen({super.key, required this.kind, required this.path});
  final LibraryKind kind;
  final List<String> path;
  @override
  ConsumerState<LibraryLevelScreen> createState() => _LibraryLevelScreenState();
}

class _LibraryLevelScreenState extends ConsumerState<LibraryLevelScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final enabled = ref.watch(sectionEnabledProvider(kind.sectionId));
    final async = ref.watch(libraryProvider(kind));
    final color = kindColor(kind);
    Future<void> refresh() => refreshContent(ref, [kind.storageKey]);

    Widget body;
    String title = kind.title;
    String? subtitle;
    if (!enabled) {
      body = const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.lock_clock_rounded,
          title: 'Temporarily unavailable',
          message: 'This library has been hidden by the admin.',
        ),
      );
    } else if (async.hasError && !async.hasValue) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(
          message:
              'Could not load ${kind.title}. Check your connection and access.',
          onRetry: refresh,
        ),
      );
    } else if (!async.hasValue) {
      body = const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(HSpace.screen),
          child: SkeletonList(count: 6),
        ),
      );
    } else {
      final loaded = async.value!;
      final r = _resolve(loaded.data);
      title = r.title ?? kind.title;
      subtitle = r.trail.isEmpty ? kind.blurb : r.trail.join(' \u203a ');
      final q = _q.toLowerCase();
      final items = q.isEmpty
          ? r.items
          : r.items.where((i) => i.title.toLowerCase().contains(q)).toList();
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (loaded.fromCache)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: OfflineHint(),
                    ),
                  Text(
                    r.levelName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (r.stats.isNotEmpty)
                    Text(
                      r.stats.map((s) => '${s.$1} ${s.$2}').join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const Gap(HSpace.md),
                  if (r.items.length > 6) ...[
                    HSearchField(
                      hint: 'Search in ${r.levelName.toLowerCase()}',
                      onChanged: (v) => setState(() => _q = v),
                    ),
                    const Gap(HSpace.md),
                  ],
                ],
              ),
            ),
            if (r.notFound)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Not found',
                  message: 'This item was moved or unpublished.',
                ),
              )
            else if (items.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.inbox_rounded,
                  title: q.isEmpty ? 'Nothing published yet' : 'No matches',
                  message: q.isEmpty
                      ? 'Check back soon \u2014 new material is added regularly.'
                      : 'Try a different word.',
                ),
              )
            else
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => items[i].build(context, color),
              ),
          ],
        ),
      );
    }
    return TabPage(
      title: title,
      subtitle: subtitle,
      onRefresh: refresh,
      slivers: [body],
    );
  }

  _Resolved _resolve(Library lib) {
    final p = widget.path;
    final k = widget.kind;
    final base = '/study/${k.name}';
    if (p.isEmpty) {
      return _Resolved(
        levelName: 'Professional years',
        stats: [
          ('${lib.years.length}', 'years'),
          ('${lib.fileCount}', 'files'),
        ],
        items: lib.years
            .map(
              (y) => _Item(
                y.label,
                (c, col) => ResourceTile(
                  icon: Icons.workspace_premium_rounded,
                  color: col,
                  surfaceColor: Color.alphaBlend(
                    col.withValues(alpha: .12),
                    Colors.white,
                  ),
                  title: y.label,
                  subtitle:
                      '${y.semesters.length} semesters \u00b7 ${y.subjectCount} subjects \u00b7 ${y.fileCount} files',
                  onTap: () => c.push('$base/${y.id}'),
                ),
              ),
            )
            .toList(),
      );
    }
    final y = lib.year(p[0]);
    if (y == null) return _Resolved.missing();
    if (p.length == 1) {
      return _Resolved(
        title: y.label,
        trail: [k.shortTitle],
        levelName: 'Semesters',
        stats: [('${y.subjectCount}', 'subjects'), ('${y.fileCount}', 'files')],
        items: y.semesters
            .map(
              (s) => _Item(
                s.label,
                (c, col) => ResourceTile(
                  icon: Icons.calendar_month_rounded,
                  color: col,
                  surfaceColor: Color.alphaBlend(
                    col.withValues(alpha: .12),
                    Colors.white,
                  ),
                  title: s.label,
                  subtitle:
                      '${s.subjects.length} subjects \u00b7 ${s.fileCount} files',
                  onTap: () => c.push('$base/${y.id}/${s.id}'),
                ),
              ),
            )
            .toList(),
      );
    }
    final se = y.semesters.where((s) => s.id == p[1]).firstOrNull;
    if (se == null) return _Resolved.missing();
    if (p.length == 2) {
      return _Resolved(
        title: se.label,
        trail: [k.shortTitle, y.label],
        levelName: 'Subjects',
        stats: [
          ('${se.subjects.length}', 'subjects'),
          ('${se.fileCount}', 'files'),
        ],
        items: se.subjects
            .map(
              (su) => _Item(
                su.label,
                (c, col) => ResourceTile(
                  icon: Icons.science_rounded,
                  color: col,
                  surfaceColor: Color.alphaBlend(
                    col.withValues(alpha: .12),
                    Colors.white,
                  ),
                  title: su.label,
                  subtitle:
                      '${su.sections.length} sections \u00b7 ${su.fileCount} files',
                  onTap: () => c.push('$base/${y.id}/${se.id}/${su.id}'),
                ),
              ),
            )
            .toList(),
      );
    }
    final su = se.subjects.where((s) => s.id == p[2]).firstOrNull;
    if (su == null) return _Resolved.missing();
    if (p.length == 3) {
      return _Resolved(
        title: su.label,
        trail: [y.label, se.label],
        levelName: 'Sections',
        stats: [('${su.topicCount}', 'topics'), ('${su.fileCount}', 'files')],
        items: su.sections
            .map(
              (sec) => _Item(
                sec.title,
                (c, col) => ResourceTile(
                  icon: Icons.folder_copy_rounded,
                  color: col,
                  surfaceColor: Color.alphaBlend(
                    col.withValues(alpha: .12),
                    Colors.white,
                  ),
                  title: sec.title,
                  subtitle:
                      '${sec.topics.length} topics \u00b7 ${sec.fileCount} files',
                  onTap: () =>
                      c.push('$base/${y.id}/${se.id}/${su.id}/${sec.id}'),
                ),
              ),
            )
            .toList(),
      );
    }
    final sec = su.sections.where((s) => s.id == p[3]).firstOrNull;
    if (sec == null) return _Resolved.missing();
    if (p.length == 4) {
      return _Resolved(
        title: sec.title,
        trail: [su.label],
        levelName: 'Topics',
        stats: [
          ('${sec.topics.length}', 'topics'),
          ('${sec.fileCount}', 'files'),
        ],
        items: sec.topics
            .map(
              (tp) => _Item(
                tp.title,
                (c, col) => ResourceTile(
                  icon: Icons.topic_rounded,
                  color: col,
                  surfaceColor: Color.alphaBlend(
                    col.withValues(alpha: .12),
                    Colors.white,
                  ),
                  title: tp.title,
                  subtitle:
                      '${tp.files.length} file${tp.files.length == 1 ? '' : 's'}',
                  onTap: () => c.push(
                    '$base/${y.id}/${se.id}/${su.id}/${sec.id}/${tp.id}',
                  ),
                ),
              ),
            )
            .toList(),
      );
    }
    final tp = sec.topics.where((t) => t.id == p[4]).firstOrNull;
    if (tp == null) return _Resolved.missing();
    final trail = [y.label, se.label, su.label, sec.title, tp.title];
    return _Resolved(
      title: tp.title,
      trail: [su.label, sec.title],
      levelName: 'Files',
      stats: [('${tp.files.length}', 'files')],
      items: tp.files
          .where((f) => f.url.isNotEmpty)
          .map(
            (f) => _Item(
              f.displayTitle,
              (c, col) => FileTile(
                file: FileRef(
                  kind: k,
                  title: f.displayTitle,
                  url: f.url,
                  trail: trail,
                ),
                color: col,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Item {
  _Item(this.title, this.build);
  final String title;
  final Widget Function(BuildContext, Color) build;
}

class _Resolved {
  _Resolved({
    required this.levelName,
    required this.items,
    this.title,
    this.trail = const [],
    this.stats = const [],
  });
  factory _Resolved.missing() =>
      _Resolved(levelName: 'Not found', items: const [])..notFound = true;
  final String levelName;
  final String? title;
  final List<String> trail;
  final List<(String, String)> stats;
  final List<_Item> items;
  bool notFound = false;
}

/// File row with live offline status (watches only its own record).
class FileTile extends ConsumerWidget {
  const FileTile({
    super.key,
    required this.file,
    required this.color,
    this.compact = false,
  });
  final bool compact;
  final FileRef file;
  final Color color;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(downloadForUrlProvider(file.url));
    Widget? badge;
    if (rec?.isReady == true) {
      badge = const StatusPill(
        label: 'Saved offline',
        color: HColors.success,
        icon: Icons.download_done_rounded,
      );
    } else if (rec?.status == DownloadStatus.downloading) {
      badge = const StatusPill(
        label: 'Downloading\u2026',
        color: HColors.info,
        icon: Icons.downloading_rounded,
      );
    }
    return ResourceTile(
      icon: documentIconForName(file.title),
      color: documentColorForName(file.title),
      title: file.title,
      subtitle: !compact && file.trail.isNotEmpty ? file.trail.last : null,
      badge: compact ? null : badge,
      compact: compact,
      trailing: Icon(Icons.open_in_full_rounded, size: 20, color: color),
      onTap: () => context.push('/viewer', extra: file),
    );
  }
}

/// Lectures (CONFIRMED pw_lectures_tree; YouTube videos play inside the app).
class LecturesScreen extends ConsumerWidget {
  const LecturesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(sectionEnabledProvider('lectures'));
    final async = ref.watch(lecturesProvider);
    Future<void> refresh() => refreshContent(ref, ['pw_lectures_tree']);
    Widget body;
    if (!enabled) {
      body = const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.play_disabled_rounded,
          title: 'Lectures are coming soon',
          message: 'The admin hasn\u2019t opened this section yet.',
        ),
      );
    } else if (async.hasError && !async.hasValue) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(
          message: 'Couldn\u2019t load lectures.',
          onRetry: refresh,
        ),
      );
    } else if (!async.hasValue) {
      body = const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(HSpace.screen),
          child: SkeletonList(),
        ),
      );
    } else {
      final years = async.value!.data;
      final rows = <Widget>[];
      for (final y in years) {
        for (final se in y.semesters) {
          for (final su in se.subjects) {
            if (su.lectures.isEmpty) continue;
            rows.add(
              Padding(
                padding: const EdgeInsets.only(
                  top: HSpace.md,
                  bottom: HSpace.xs,
                ),
                child: SectionHeader(title: '${su.label} \u00b7 ${y.label}'),
              ),
            );
            for (final l in su.lectures) {
              rows.add(
                ResourceTile(
                  icon: Icons.play_circle_fill_rounded,
                  color: HColors.lectures,
                  title: l.title,
                  subtitle: se.label,
                  trailing: const Icon(Icons.play_arrow_rounded, size: 20),
                  onTap: () => l.uri == null
                      ? showHSnack(context, 'Link missing', error: true)
                      : context.push('/lecture-player', extra: {'title': l.title, 'url': l.uri.toString()}),
                ),
              );
            }
          }
        }
      }
      body = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
        sliver: SliverList.list(
          children: [
            const HeroPanel(
              eyebrow: 'Video',
              title: 'Lectures',
              icon: Icons.play_circle_rounded,
              color: HColors.lectures,
            ),
            ...rows.isEmpty
                ? [
                    const EmptyState(
                      icon: Icons.video_library_outlined,
                      title: 'No lectures yet',
                    ),
                  ]
                : rows,
          ],
        ),
      );
    }
    return TabPage(title: 'Lectures', onRefresh: refresh, slivers: [body]);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../app/providers.dart';
import '../../auth/domain/reference_data.dart';
import '../../../core/utils/links.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../content/data/content_providers.dart';
import '../../downloads/data/downloads_controller.dart';
import '../../downloads/domain/download_record.dart';
import '../../academics/data/drive_gateway.dart';
import '../../pdf_studio/data/studio_pdf_engine.dart';
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
              HeroPanel(
                eyebrow: 'Your library',
                title: 'Every library, at your fingertips.',
                subtitle: 'Your notes, videos and exam practice in one place.',
                icon: Icons.school_rounded,
              ),
              TextButton.icon(
                onPressed: () => context.open('/profile/edit'),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Change professional year'),
              ),
              const Gap(HSpace.lg),
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
      final breadcrumbs = _breadcrumbs(loaded.data);
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
                  HeroPanel(
                    eyebrow: r.levelName,
                    title: title,
                    subtitle: widget.path.isEmpty ? kind.blurb : null,
                    icon: kindIcon(kind),
                    color: color,
                    stats: r.stats,
                  ),
                  if (widget.path.isNotEmpty && breadcrumbs.isNotEmpty) ...[
                    const Gap(HSpace.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < breadcrumbs.length; i++) ...[
                            if (i > 0)
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            TextButton(
                              onPressed: i == breadcrumbs.length - 1
                                  ? null
                                  : () => context.go(
                                      '/study/${kind.name}${breadcrumbs[i].path.isEmpty ? '' : '/${breadcrumbs[i].path.join('/')}'}',
                                    ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                              ),
                              child: Text(
                                breadcrumbs[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
            else if (r.fileGallery)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: HSpace.md),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 252,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => items[i].build(context, color),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: HSpace.md),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    mainAxisExtent: 148,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => items[i].build(context, color),
                ),
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

  List<_Crumb> _breadcrumbs(Library lib) {
    final p = widget.path;
    if (p.isEmpty) return const [];
    final crumbs = <_Crumb>[_Crumb(widget.kind.shortTitle, const [])];
    final year = lib.year(p[0]);
    if (year == null) return crumbs;
    crumbs.add(_Crumb(year.label, [year.id]));
    if (p.length < 2) return crumbs;
    final semester = year.semesters.where((s) => s.id == p[1]).firstOrNull;
    if (semester == null) return crumbs;
    crumbs.add(_Crumb(semester.label, [year.id, semester.id]));
    if (p.length < 3) return crumbs;
    final subject = semester.subjects.where((s) => s.id == p[2]).firstOrNull;
    if (subject == null) return crumbs;
    crumbs.add(_Crumb(subject.label, [year.id, semester.id, subject.id]));
    if (p.length < 4) return crumbs;
    final section = subject.sections.where((s) => s.id == p[3]).firstOrNull;
    if (section == null) return crumbs;
    crumbs.add(
      _Crumb(section.title, [year.id, semester.id, subject.id, section.id]),
    );
    if (p.length < 5) return crumbs;
    final topic = section.topics.where((t) => t.id == p[4]).firstOrNull;
    if (topic == null) return crumbs;
    crumbs.add(
      _Crumb(
        topic.title,
        [year.id, semester.id, subject.id, section.id, topic.id],
      ),
    );
    return crumbs;
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
                (c, col) => _FolderCard(
                  icon: Icons.workspace_premium_rounded,
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
                (c, col) => _FolderCard(
                  icon: Icons.calendar_month_rounded,
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
                (c, col) => _FolderCard(
                  icon: Icons.science_rounded,
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
                (c, col) => _FolderCard(
                  icon: Icons.folder_copy_rounded,
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
                (c, col) => _FolderCard(
                  icon: Icons.topic_rounded,
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
      fileGallery: true,
      items: tp.files
          .where((f) => f.url.isNotEmpty)
          .map(
            (f) => _Item(
              f.displayTitle,
              (c, col) => _StudyPdfCard(
                file: FileRef(
                  kind: k,
                  title: f.displayTitle,
                  url: f.url,
                  trail: trail,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Crumb {
  const _Crumb(this.title, this.path);
  final String title;
  final List<String> path;
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: .7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: ink, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 11, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyPdfCard extends ConsumerWidget {
  const _StudyPdfCard({required this.file});
  final FileRef file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(downloadForUrlProvider(file.url));
    final localPath = record?.isAvailableOffline == true
        ? record!.localPath
        : null;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: .7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/viewer', extra: file),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 5),
                child: _StudyPdfPreview(
                  key: ValueKey(localPath ?? file.url),
                  url: file.url,
                  localPath: localPath,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 2),
              child: Text(
                file.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 10),
              child: Text(
                record?.isAvailableOffline == true
                    ? 'Saved offline'
                    : 'PDF document',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenderedStudyPage {
  const _RenderedStudyPage(this.bytes);
  final Uint8List bytes;
}

class _ResolvedStudyThumbnail {
  const _ResolvedStudyThumbnail(this.request);
  final DocumentRequest request;
}

class _StudyPdfPreview extends StatefulWidget {
  const _StudyPdfPreview({
    super.key,
    required this.url,
    this.localPath,
  });

  final String url;
  final String? localPath;

  @override
  State<_StudyPdfPreview> createState() => _StudyPdfPreviewState();
}

class _StudyPdfPreviewState extends State<_StudyPdfPreview> {
  late Future<Object?> _preview;

  @override
  void initState() {
    super.initState();
    _preview = _load();
  }

  @override
  void didUpdateWidget(covariant _StudyPdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.localPath != widget.localPath) {
      _preview = _load();
    }
  }

  Future<Object?> _load() async {
    final path = widget.localPath;
    if (!kIsWeb && path != null && path.toLowerCase().endsWith('.pdf')) {
      try {
        final page = await StudioPdfEngine.renderPage(path, 0);
        return _RenderedStudyPage(page.bytes);
      } catch (_) {
        // Try the Drive-generated real thumbnail below.
      }
    }
    try {
      return _ResolvedStudyThumbnail(
        await DriveGateway.instance.resolve(widget.url),
      );
    } catch (_) {
      return null;
    }
  }

  Widget _unavailable(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: .45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined, color: muted, size: 26),
              const SizedBox(height: 6),
              Text(
                'Preview unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Object?>(
    future: _preview,
    builder: (context, snapshot) {
      final value = snapshot.data;
      if (value is _RenderedStudyPage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Colors.white,
            child: Image.memory(
              value.bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        );
      }
      if (value is _ResolvedStudyThumbnail) {
        final url = value.request.thumbnailUrl;
        if (url != null && url.startsWith('https://')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              headers: value.request.headers,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _unavailable(context),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    ),
            ),
          );
        }
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        );
      }
      return _unavailable(context);
    },
  );
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
    this.fileGallery = false,
  });
  factory _Resolved.missing() =>
      _Resolved(levelName: 'Not found', items: const [])..notFound = true;
  final String levelName;
  final String? title;
  final List<String> trail;
  final List<(String, String)> stats;
  final List<_Item> items;
  final bool fileGallery;
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

/// Lectures (CONFIRMED pw_lectures_tree; YouTube links open in YouTube app/browser).
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
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                  onTap: () => l.uri == null
                      ? showHSnack(context, 'Link missing', error: true)
                      : openLink(context, l.uri.toString()),
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

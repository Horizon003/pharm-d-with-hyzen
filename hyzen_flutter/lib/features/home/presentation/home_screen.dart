import '../../../core/widgets/reward_art.dart';
import '../../study_progress/reward_controller.dart';
import '../../../core/widgets/polish_ui.dart';
import '../../search/presentation/home_search.dart';
import '../../notifications/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../academics/domain/models.dart';
import '../../academics/presentation/library_screens.dart';
import '../../academics/presentation/discovery_widgets.dart';
import '../../content/data/content_providers.dart';
import '../../downloads/data/downloads_controller.dart';
import '../../downloads/domain/download_record.dart';
import '../../shell/app_shell.dart';
import '../../study_progress/study_tracker.dart';
import '../../study_progress/campus_rank_screen.dart';
import '../data/recent_controller.dart';
import 'home_dashboard_top.dart';
import 'announcement_carousel.dart';

final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
String homeGreeting(DateTime time) {
  if (time.hour < 5 || time.hour >= 23) return 'Good night';
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 16) return 'Good afternoon';
  return 'Good evening';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final user = ref.watch(authStateProvider).valueOrNull;
    final name =
        profile?.firstName ?? user?.displayName?.split(' ').first ?? 'there';
    final recent = ref.watch(recentProvider);
    final slides = ref.watch(announcementSlidesProvider);
    final downloads = ref.watch(downloadsProvider).values;
    final saved = downloads.where((r) => r.isAvailableOffline).length;
    final fresh = downloads
        .where((r) => r.isAvailableOffline && r.unopened)
        .length;
    final active = downloads
        .where((r) => r.status == DownloadStatus.downloading)
        .length;
    final downloadLabels = [
      if (saved > 0) '$saved Saved',
      if (fresh > 0) '$fresh New',
      if (active > 0) '$active Downloading',
    ];
    return TabPage(
      title: 'Home',
      headerExtent: 88 + MediaQuery.textScalerOf(context).scale(12),
      integratedHeader: true,
      header: _HomeHeader(
        name: name,
        photoUrl: ProfileAvatar.resolveUrl(profile?.photoUrl, user?.photoURL),
      ),
      onRefresh: () => refreshContent(ref, [
        'pw_settings',
        'pw_announcement',
        ...LibraryKind.values.map((k) => k.storageKey),
      ]),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: [
              HomeDashboardTop(year: profile?.professionalYear),
              const SizedBox(height: 16),
              const HomeSearch(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your plan',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('home-professional-badge'),
                    onPressed: () => context.push('/profile'),
                    child: Text(
                      profile?.professionalYear == null
                          ? 'Your year'
                          : 'Year ${profile!.professionalYear}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const _PlanCards(),
              const SizedBox(height: 14),
              const _StudyStats(),
              if (downloadLabels.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: [
                    for (final label in downloadLabels)
                      TextButton(
                        onPressed: () => context.go('/downloads'),
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              if (ref.watch(boolPrefProvider('pref_announcements')) &&
                  slides.isNotEmpty) ...[
                const SizedBox(height: 8),
                AnnouncementCarousel(slides: slides),
                const SizedBox(height: 8),
              ],
              if (recent.isNotEmpty) ...[
                SectionHeader(
                  title: 'Last lessons',
                  action: 'Clear',
                  onAction: () async {
                    if (await confirmDialog(
                      context,
                      title: 'Clear recent history?',
                      message:
                          'Only recently opened history will be cleared. Your files stay saved.',
                      confirm: 'Clear history',
                    )) {
                      await ref.read(recentProvider.notifier).clear();
                    }
                  },
                ),
                for (final item in recent.take(3))
                  FileTile(
                    file: item.file,
                    color: HColors.notes,
                    compact: true,
                  ),
              ],
              const SizedBox(height: 14),
              const SubjectDiscovery(compact: true),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCards extends StatelessWidget {
  const _PlanCards();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final large = MediaQuery.textScalerOf(context).scale(22) > 22 * 1.3;
    Widget planCard({required bool library}) {
      final title = library ? 'Study library' : 'Office workspace';
      final semantic = library ? 'Study Library' : 'Office Workspace';
      final route = library ? '/study' : '/pdf-studio';
      final color = library ? HColors.apricot : HColors.blue;
      return HCard(
        color: color,
        radius: 24,
        shadow: false,
        semanticLabel: semantic,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: library
              ? [const Color(0xffffc47c), const Color(0xffffe4cf)]
              : [const Color(0xffa9c9f4), const Color(0xffe0e8f9)],
        ),
        padding: const EdgeInsets.all(14),
        onTap: () => context.go(route),
        onLongPress: () => showCardPreview(
          context,
          title: semantic,
          description: library
              ? 'Explore professional-year notes, practice MCQs, past papers and guide books. Continue with your subjects at your own pace.'
              : 'Scan pages, import PDFs, crop and organise documents, annotate files and search recognised text.',
          asset: library ? 'action-notes' : 'action-scan',
          color: color,
          onOpen: () => context.go(route),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlanTag(library ? 'Learn' : 'Create'),
            const SizedBox(height: 10),
            Text(
              title,
              style: t.textTheme.headlineSmall?.copyWith(
                fontSize: 19,
                height: 1.18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              library ? 'Notes, MCQs & past papers' : 'Scan · PDF · Documents',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: RewardArt(
                library ? 0 : 1,
                size: large
                    ? 116
                    : library
                    ? 140
                    : 112,
              ),
            ),
          ],
        ),
      );
    }

    Widget library() => planCard(library: true);
    Widget office() => planCard(library: false);
    Widget goals() => const _HomeQuickActions();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (large || constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              library(),
              const SizedBox(height: 10),
              office(),
              const SizedBox(height: 10),
              goals(),
            ],
          );
        }

        // Reserve space for the three 48dp controls in the side column.
        final rightWidth = (constraints.maxWidth * .45).clamp(156.0, 260.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: library()),
            const SizedBox(width: 10),
            SizedBox(
              width: rightWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [office(), const SizedBox(height: 10), goals()],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions();
  @override
  Widget build(BuildContext context) => Material(
    color: HColors.pink,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final action in const [
            ('notes', 'Open notes', '/study/notes'),
            ('scan', 'Scan a document', '/create-pdf?source=camera'),
            ('downloads', 'Open downloads', '/downloads'),
          ])
            IconButton(
              key: ValueKey('home-action-${action.$1}'),
              tooltip: action.$2,
              onPressed: () => context.push(action.$3),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                maximumSize: const Size(48, 48),
                padding: const EdgeInsets.all(4),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: Ink(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xB3FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(
                    'assets/reference/action-${action.$1}.png',
                    cacheWidth: 120,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _PlanTag extends StatelessWidget {
  const _PlanTag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    ),
  );
}

class _StudyStats extends ConsumerWidget {
  const _StudyStats();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(studyTrackerProvider);
    final board = ref.watch(campusBoardProvider('week')).valueOrNull;
    final entries = [
      (
        '${ref.watch(rewardProvider).streak} days',
        'Streak',
        '/study-streak',
        'icon-streak',
      ),
      (
        '${p.weekSeconds ~/ 3600}h ${(p.weekSeconds ~/ 60) % 60}m',
        'Time spent',
        '/study-progress',
        'icon-time',
      ),
      (
        board?.mine?.rank == null ? '—' : '#${board!.mine!.rank}',
        'Prof. Rank',
        '/campus-rank',
        'icon-rank',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columns = MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 1 : 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in entries)
              SizedBox(
                width: (c.maxWidth - (columns - 1) * 8) / columns,
                child: HCard(
                  radius: 22,
                  outlineColor: const Color(0xFFD2CADF),
                  shadow: false,
                  onTap: () => context.push(e.$3),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HAssetIcon(e.$4, size: 30),
                      const SizedBox(height: 6),
                      Text(
                        e.$1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(e.$2, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc;
  @override
  Widget build(BuildContext context) {
    final title = doc == 'privacy' ? 'Privacy Policy' : 'Terms of Use';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: HTopBar(title: title),
      body: HBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              HSpace.screen,
              80,
              HSpace.screen,
              HSpace.screen,
            ),
            child: PanelBlock(
              child: Text(
                'The official $title has not been supplied yet. The Hyzen owner must provide the final text before public release.\n\n'
                'Summary of current practice: your sign-in details are protected by the account service; your profile '
                '(name, mobile, city, professional year, institution) is stored in your private students record; '
                'offline files stay on your device.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends ConsumerStatefulWidget {
  const _HomeHeader({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;
  @override
  ConsumerState<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<_HomeHeader> {
  bool showPoints = true;
  @override
  Widget build(BuildContext context) {
    final reward = ref.watch(rewardProvider);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 12,
              left: 96,
              right: 96,
              child: Text(
                'Hello, ${widget.name}',
                key: const ValueKey('home-greeting'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 88,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Profile & settings',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showAccountMenu(context),
                          child: SizedBox.square(
                            dimension: 48,
                            child: Center(
                              child: ProfileAvatar(
                                photoUrl: widget.photoUrl,
                                radius: 21,
                                fallback: widget.name,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (reward.badges.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final day in reward.badges.take(3))
                              RewardArt(
                                10 + rewardMilestones.indexOf(day),
                                size: 16,
                              ),
                          ],
                        ),
                      if (showPoints)
                        InkWell(
                          onTap: () => setState(() => showPoints = false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xfff4e3d8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'My Points ${reward.points}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    HGlassButton(
                      icon: 'icon-search',
                      label: 'Search academic resources',
                      onTap: () => context.go('/search', extra: true),
                    ),
                    HGlassButton(
                      icon: 'icon-bell',
                      label: 'Notifications',
                      badge: ref
                          .watch(notificationsProvider)
                          .where((m) => m['read'] != true)
                          .length,
                      onTap: () => context.push('/notifications'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

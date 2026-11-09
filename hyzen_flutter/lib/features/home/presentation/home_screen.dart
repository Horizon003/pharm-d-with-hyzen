import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/main_dock.dart';
import '../../../core/widgets/surfaces.dart';
import '../../downloads/domain/download_record.dart';
import 'home_background.dart';
import 'home_dashboard_top.dart';
import 'home_time_artwork.dart';
import 'announcement_carousel.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../notifications/notifications_screen.dart';
import '../../academics/domain/models.dart';
import '../../academics/presentation/library_screens.dart';
import '../../academics/presentation/discovery_widgets.dart';
import '../../content/data/content_providers.dart';
import '../../shell/app_shell.dart';
import '../../auth/presentation/auth_controllers.dart';
import '../data/recent_controller.dart';
import '../../downloads/data/downloads_controller.dart';

// The reference artwork is decorative; all controls below are live Flutter UI.
final homeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
String homeGreeting(DateTime time) {
  final greeting = HomeTimePhase.at(time).greeting;
  return greeting[0] + greeting.substring(1).toLowerCase();
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(siteSettingsProvider);
    final recent = ref.watch(recentProvider);
    final ann = ref.watch(boolPrefProvider('pref_announcements'))
        ? ref.watch(announcementSlidesProvider)
        : ref.watch(announcementSlidesProvider).take(0).toList();
    final name =
        profile?.firstName ?? user?.displayName?.split(' ').first ?? 'there';
    final fresh = ref.watch(lastCreatedProfileProvider)?.uid == user?.uid;
    final counts = ref.watch(
      downloadsProvider.select(
        (map) => (
          map.values
              .where((r) => r.status == DownloadStatus.downloading)
              .length,
          map.values.where((r) => r.isAvailableOffline).length,
          map.values.where((r) => r.isAvailableOffline && r.unopened).length,
        ),
      ),
    );
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final badges = [
      if (counts.$1 > 0) '${counts.$1} Downloading',
      if (counts.$2 > 0) '${counts.$2} Saved',
      if (counts.$3 > 0) '${counts.$3} New',
    ];
    Widget grid(List<Widget> children, double height) => GridView(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: scale > 1.3 ? 1 : 2,
        mainAxisExtent: height * scale.clamp(1, 2),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      children: children,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: TabPage(
        title: 'PHARM D',
        integratedHeader: true,
        headerTheme: Theme.of(context),
        header: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Profile & settings',
                    child: InkWell(
                      onTap: () => showAccountMenu(context),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: profile?.photoUrl != null
                              ? ProfileAvatar(
                                  photoUrl: profile!.photoUrl,
                                  radius: 20,
                                  fallback: name,
                                )
                              : Image.asset(
                                  'assets/brand/hyzen_icon_square.png',
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (scale <= 1.3)
                          Text(
                            homeGreeting(
                              ref.watch(homePhaseClockProvider).value,
                            ).toUpperCase(),
                            key: const ValueKey('home-greeting'),
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: .7,
                              fontWeight: FontWeight.w700,
                              color: dark
                                  ? Colors.white70
                                  : const Color(0xFF436187),
                            ),
                          ),
                        Tooltip(
                          message: name,
                          child: Text(
                            fresh ? 'Welcome, $name' : 'Welcome back, $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: dark
                                  ? Colors.white
                                  : const Color(0xFF0C1933),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
            ),
          ),
        ),
        homeBackground: (child) => HomeAtmosphere(child: child),
        onRefresh: () => refreshContent(ref, [
          'pw_settings',
          'pw_announcement',
          ...LibraryKind.values.map((k) => k.storageKey),
        ]),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                HomeDashboardTop(year: profile?.professionalYear),
                HomeAtmosphere(
                  content: true,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      8 + MainDock.contentInset(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(32),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => context.go('/search', extra: true),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Search subjects, topics or files',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      IconButton(tooltip: 'Scan a document',
                                        onPressed: () => context.push('/create-pdf'),
                                        icon: Icon(
                                          Icons.document_scanner_outlined,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (ann.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnnouncementCarousel(slides: ann),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Quick Access',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/study'),
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                        const Gap(10),
                        grid([
                          _ReferenceCard(
                            title: 'Study Library',
                            subtitle: 'Your academic library',
                            icon: Icons.menu_book_outlined,
                            art: 'books',
                            black: true,
                            onTap: () => context.go('/study'),
                          ),
                          _ReferenceCard(
                            title: 'Office Workspace',
                            subtitle: 'Scan, read & create',
                            icon: Icons.document_scanner_outlined,
                            art: 'papers',
                            onTap: () => context.go('/pdf-studio'),
                          ),
                        ], 116),
                        const Gap(14),
                        Text(
                          'Others',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Gap(8),
                        Row(
                          children: [
                            Expanded(
                              child: _CompactHomeLink(
                                label: settings.sectionEnabled('shop')
                                    ? 'Shop'
                                    : 'Search',
                                icon: settings.sectionEnabled('shop')
                                    ? Icons.storefront_outlined
                                    : Icons.search,
                                onTap: () => settings.sectionEnabled('shop')
                                    ? context.go('/shop')
                                    : context.go('/search', extra: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CompactHomeLink(
                                label: 'Downloads',
                                icon: Icons.file_download_outlined,
                                badges: badges,
                                onTap: () => context.go('/downloads'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CompactHomeLink(
                                label: 'Study Plan',
                                icon: Icons.calendar_month_outlined,
                                onTap: () => context.push('/study-goals'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CompactHomeLink(
                                label: 'My Progress',
                                icon: Icons.bar_chart_rounded,
                                onTap: () => context.push('/study-progress'),
                              ),
                            ),
                          ],
                        ),
                        const Gap(20),
                        if (recent.isNotEmpty) ...[
                          const Gap(24),
                          SectionHeader(
                            title: 'Continue studying',
                            action: 'Clear',
                            onAction: () async {
                              if (await confirmDialog(
                                context,
                                title: 'Clear recent history?',
                                message:
                                    'Only the list of recently opened files will be cleared. Your downloads and original documents stay saved.',
                                confirm: 'Clear history',
                              )) {
                                await ref.read(recentProvider.notifier).clear();
                              }
                            },
                          ),
                          for (final item in recent.take(3))
                            FileTile(
                              file: item.file,
                              color: Theme.of(context).colorScheme.primary,
                              compact: true,
                            ),
                        ],
                        const Gap(16),
                        const SubjectDiscovery(compact: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.art,
    required this.onTap,
    this.black = false,
  });
  final String title, subtitle, art;
  final IconData icon;
  final VoidCallback onTap;
  final bool black;
  @override
  Widget build(BuildContext context) {
    final ink = black || Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Semantics(
      button: true,
      label: title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: black
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D2F5C),
                    Color(0xFF174E8B),
                    Color(0xFF91B7D8),
                  ],
                  stops: [0, .58, 1],
                )
              : null,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Material(
          color: black
              ? Colors.transparent
              : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF212123)
                    : Colors.white),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -6,
                  bottom: -8,
                  child: ExcludeSemantics(
                    child: Image.asset(
                      'assets/home/$art.webp',
                      width: 58,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: ink, size: 25),
                          const Spacer(),
                          Icon(Icons.arrow_outward, color: ink, size: 17),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const Gap(4),
                      Padding(
                        padding: const EdgeInsets.only(right: 56),
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink.withValues(alpha: .72),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactHomeLink extends StatelessWidget {
  const _CompactHomeLink({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badges = const [],
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final List<String> badges;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: dark ? 0 : 2,
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height:
              ((68 + 12 * badges.length) *
                      MediaQuery.textScalerOf(context).scale(1))
                  .clamp(68.0, 260.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final badge in badges)
                  Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
                'Summary of current practice: your password is handled only by Firebase Authentication; your profile '
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../notifications/notifications_screen.dart';
import '../home/presentation/home_background.dart';
import '../updates/update_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/main_dock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/widgets/profile_avatar.dart';
import '../profile/presentation/profile_screens.dart';
import '../profile/presentation/widgets/account_widgets.dart';
import '../../app/safe_nav.dart';

/// Authenticated shell: Material navigation with Android back handling.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = navigationShell.currentIndex;
    final path = GoRouterState.of(context).uri.path;
    final account = path.startsWith('/profile') || path == '/settings';
    final reader = path.startsWith('/pdf-studio/viewer/');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (FocusManager.instance.primaryFocus?.hasFocus == true &&
            MediaQuery.viewInsetsOf(context).bottom > 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          return;
        }
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        if (idx != 0) {
          navigationShell.goBranch(0);
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Close PHARM D WITH HYZEN?'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileAvatar(photoUrl: null, radius: 44),
                SizedBox(height: 16),
                Text(
                  'Ready to take a break? Your study progress and downloads are saved.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep studying'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Close app'),
              ),
            ],
          ),
        );
        if (leave == true) {
          ref.read(sessionRevisionProvider.notifier).state++;
          navigationShell.goBranch(0, initialLocation: true);
          await SystemNavigator.pop();
        }
      ),
      child: Scaffold(
        extendBody: true,
        body: UpdateGate(
          child: AnimatedSwitcher(
            duration: HMotion.fast,
            reverseDuration: const Duration(milliseconds: 120),
            switchInCurve: HMotion.curve,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [
                ...previous,
                if (current != null) current,
              ],
            ),
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0.018, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(path),
              child: navigationShell,
            ),
          ),
        ),
        bottomNavigationBar: reader || account
            ? null
            : MainDock(
                path: path,
                onSelected: (destination) => navigationShell.goBranch(
                  destination.branchIndex,
                  initialLocation: idx == destination.branchIndex,
                ),
              ),
      ),
    );
  }
}

/// Standard tab page: persistent opaque top bar + background + bottom padding for nav.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.onRefresh,
    this.subtitle,
    this.drawer,
    this.homeBackground,
    this.integratedHeader = false,
    this.headerTheme,
    this.header,
  });
  final Widget Function(Widget child)? homeBackground;
  final bool integratedHeader;
  final ThemeData? headerTheme;
  final Widget? header;
  final Widget? drawer;
  final String title;
  final String? subtitle;
  final List<Widget> slivers;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final headerHeight = header != null
        ? 64.0
        : (scaler.scale(22) * 1.25 +
                  (subtitle != null ? scaler.scale(11) * 1.4 : 0) +
                  12)
              .clamp(64.0, 160.0);
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).top + headerHeight + 8,
          ),
        ),
        ...slivers,
        if (homeBackground == null)
          SliverToBoxAdapter(
            child: SizedBox(height: MainDock.contentInset(context)),
          ),
      ],
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: drawer,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(headerHeight),
        child: Theme(
          data: headerTheme ?? Theme.of(context),
          child:
              header ??
              _Bar(
                height: headerHeight,
                integrated: integratedHeader,
                onAccount: () => showAccountMenu(context),
                title: title,
                subtitle: subtitle,
                actions: actions,
                showMenu: drawer != null,
              ),
        ),
      ),
      body: homeBackground != null
          ? homeBackground!(
              onRefresh == null
                  ? scroll
                  : RefreshIndicator(
                      onRefresh: onRefresh!,
                      edgeOffset: headerHeight,
                      child: scroll,
                    ),
            )
          : HomeAtmosphere(
              content: true,
              child: onRefresh == null
                  ? scroll
                  : RefreshIndicator(
                      onRefresh: onRefresh!,
                      edgeOffset: headerHeight,
                      child: scroll,
                    ),
            ),
    );
  }
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar({
    required this.title,
    this.height = 64,
    this.subtitle,
    this.actions = const [],
    this.showMenu = false,
    this.integrated = false,
    this.onAccount,
  });
  final bool integrated;
  final VoidCallback? onAccount;
  final bool showMenu;
  final double height;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Size get preferredSize => Size.fromHeight(height);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final header = SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (showMenu)
              IconButton(
                tooltip: 'Admin menu',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            // The root Home page can appear poppable when another tab has a
            // nested route in its retained navigator. Never show a dead
            // back arrow on the Home header.
            else if (!const [
                  'PHARM D',
                  'Study',
                  'Search',
                  'Office Workspace',
                  'Downloads',
                  'Profile',
                  'Settings',
                  'Shop',
                ].contains(title) &&
                Navigator.of(context).canPop())
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            else
              const SizedBox(width: HSpace.screen),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title == 'PHARM D')
                    Row(
                      children: [
                        Image.asset(
                          'assets/brand/hyzen_icon_square.png',
                          width: integrated ? 24 : 30,
                          height: integrated ? 24 : 30,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'PHARM D ',
                                  style: TextStyle(
                                    color: t.colorScheme.onSurface,
                                  ),
                                ),
                                TextSpan(
                                  text: 'WITH HYZEN',
                                  style: TextStyle(
                                    color: t.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: integrated ? 13 : 17,
                              letterSpacing: -.2,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.4,
                      ),
                    ),
                  if (subtitle != null && title != 'PHARM D')
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            ...actions,
            const NotificationBell(),
            Consumer(
              builder: (context, ref, _) {
                final profile = ref.watch(profileProvider).valueOrNull;
                return Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Tooltip(
                    message: 'Profile & settings',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAccount ?? () => showAccountMenu(context),
                      child: Padding(
                        padding: EdgeInsets.all(integrated ? 6 : 0),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: t.colorScheme.primary,
                              width: 1.6,
                            ),
                          ),
                          child: ProfileAvatar(
                            photoUrl: profile?.photoUrl,
                            radius: 16,
                            fallback: profile?.firstName ?? 'H',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
    return integrated
        ? DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Color(0xF2000000)],
              ),
            ),
            child: header,
          )
        : SurfacePanel(radius: 0, child: header);
  }
}

/// Small "offline copy" hint shown when content came from cache.
class OfflineHint extends StatelessWidget {
  const OfflineHint({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      HSpace.screen,
      0,
      HSpace.screen,
      HSpace.sm,
    ),
    child: Row(
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          'Showing saved copy \u00b7 pull to refresh',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

/// Account sheet behind the top-right avatar (Q03 / Q15): Profile, Settings,
/// Downloads, Orders and Notifications without adding bottom tabs.
Future<void> showAccountMenu(BuildContext context) {
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AccountStyle.theme(context).scaffoldBackgroundColor,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: .96,
      child: AccountTheme(
        child: ProfileScreen(
          onClose: () => Navigator.pop(sheetContext),
          onNavigate: (path) {
            Navigator.pop(sheetContext);
            openRoute(router, path);
          },
        ),
      ),
    ),
  );
}

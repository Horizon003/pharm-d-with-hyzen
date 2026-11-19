import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/content/data/content_providers.dart';
import '../theme/tokens.dart';
import 'polish_ui.dart';
import 'soft_pill_bar.dart';
import 'display_preferences.dart';

enum DockDestination {
  home('Home', '/home', 0, Icons.home_outlined),
  study('Study', '/study', 1, Icons.grid_view_rounded),
  office('Office Workspace', '/pdf-studio', 3, Icons.description_outlined),
  shop('Shop', '/shop', 6, Icons.shopping_bag_outlined),
  downloads('Downloads', '/downloads', 4, Icons.file_download_outlined);

  const DockDestination(this.label, this.route, this.branchIndex, this.icon);
  final String label, route;
  final int branchIndex;
  final IconData icon;
  bool matches(String path) => path == route || path.startsWith('$route/');
}

/// Compact pill dock from the reference. Navigation stacks stay in the shell.
class MainDock extends ConsumerWidget {
  const MainDock({super.key, required this.path, required this.onSelected});
  final String path;
  final ValueChanged<DockDestination> onSelected;
  static double height(BuildContext context) =>
      (48 * UiDensity.of(context)).clamp(48.0, 56.0) + 12;
  static double contentInset(BuildContext context) =>
      height(context) +
      16 +
      math.max(10, MediaQuery.viewPaddingOf(context).bottom);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final selected = DockDestination.values.indexWhere((d) => d.matches(path));
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: SoftPillBar(
            key: const ValueKey('main-dock'),
            selectedIndex: selected,
            items: [
              for (final d in DockDestination.values)
                SoftPillItem(
                  key: ValueKey('dock-${d.name}'),
                  label: d.label,
                  shortLabel: d == DockDestination.office ? 'Office' : null,
                  icon: HAssetIcon(switch (d) {
                    DockDestination.home => 'icon-home',
                    DockDestination.study => 'action-notes',
                    DockDestination.office => 'action-scan',
                    DockDestination.shop => 'icon-shop',
                    DockDestination.downloads => 'action-downloads',
                  }, size: 24),
                  onTap: () => onSelected(d),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showStudyMenu(BuildContext context) {
  final router = GoRouter.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close study menu',
    barrierColor: Colors.black12,
    transitionDuration: HMotion.duration(context),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .05),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    pageBuilder: (c, _, __) => Consumer(
      builder: (c, ref, _) {
        final settings = ref.watch(siteSettingsProvider);
        final t = Theme.of(c);
        var expanded = true;
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: (MediaQuery.sizeOf(c).width * .16).clamp(12, 150),
                bottom: 92,
                right: 16,
              ),
              child: StatefulBuilder(
                builder: (c, setState) => SizedBox(
                  width: 216,
                  child: Material(
                    color: t.colorScheme.surface,
                    elevation: 10,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.max(
                          180,
                          MediaQuery.sizeOf(c).height - 150,
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (settings.sectionEnabled('notes')) ...[
                              _StudyRow(
                                'Notes',
                                Icons.menu_book_rounded,
                                Theme.of(context).colorScheme.primary,
                                () => setState(() => expanded = !expanded),
                                expanded: expanded,
                              ),
                              if (expanded)
                                Container(
                                  margin: const EdgeInsets.only(
                                    left: 25,
                                    bottom: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.colorScheme.primary.withValues(
                                      alpha: .07,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      _StudyRow(
                                        'Regular',
                                        Icons.description_outlined,
                                        t.colorScheme.onSurfaceVariant,
                                        () {
                                          Navigator.pop(c);
                                          router.go('/study/notes');
                                        },
                                        small: true,
                                      ),
                                      if (settings.sectionEnabled('special'))
                                        _StudyRow(
                                          'Special',
                                          Icons.auto_stories_outlined,
                                          t.colorScheme.onSurfaceVariant,
                                          () {
                                            Navigator.pop(c);
                                            router.go('/study/special');
                                          },
                                          small: true,
                                        ),
                                    ],
                                  ),
                                ),
                              const Divider(height: 9),
                            ],
                            if (settings.sectionEnabled('mcqs'))
                              _StudyRow(
                                'MCQs',
                                Icons.quiz_rounded,
                                HColors.mcqs,
                                () {
                                  Navigator.pop(c);
                                  router.go('/study/mcqs');
                                },
                              ),
                            if (settings.sectionEnabled('papers'))
                              _StudyRow(
                                'PPS',
                                Icons.assignment_rounded,
                                HColors.special,
                                () {
                                  Navigator.pop(c);
                                  router.go('/study/papers');
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _StudyRow extends StatelessWidget {
  const _StudyRow(
    this.label,
    this.icon,
    this.color,
    this.onTap, {
    this.small = false,
    this.expanded,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool small;
  final bool? expanded;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: small ? 8 : 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: small ? 20 : 23),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: small ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!small)
            Icon(
              expanded == true
                  ? Icons.expand_more_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
            ),
        ],
      ),
    ),
  );
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/content/data/content_providers.dart';
import '../theme/tokens.dart';
import 'navigation_preferences.dart';

/// Visible destinations map to the existing shell branches. Auxiliary branches
/// keep their original indexes; they are intentionally absent from this list.
enum DockDestination {
  home('Home', '/home', 0, Icons.home_outlined),
  study('Study', '/study', 1, Icons.menu_book_outlined),
  office('Office Workspace', '/pdf-studio', 3, Icons.description_outlined),
  shop('Shop', '/shop', 6, Icons.storefront_outlined),
  downloads('Downloads', '/downloads', 4, Icons.file_download_outlined);

  const DockDestination(this.label, this.route, this.branchIndex, this.icon);
  final String label, route;
  final int branchIndex;
  final IconData icon;
  bool matches(String path) => path == route || path.startsWith('$route/');
}

/// One opaque, five-destination dock. The shell owns navigation and restores
/// each branch's existing stack; the current route alone determines selection.
class MainDock extends ConsumerWidget {
  const MainDock({super.key, required this.path, required this.onSelected});
  final String path;
  final ValueChanged<DockDestination> onSelected;

  static double height(BuildContext context) =>
      48.0 + math.max(22.0, MediaQuery.textScalerOf(context).scale(11) * 2.4);
  static double contentInset(BuildContext context) =>
      height(context) * 1.25 +
      16 +
      math.max(10.0, MediaQuery.viewPaddingOf(context).bottom);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dockThemeProvider);
    final size = ref.watch(dockSizeProvider);
    final dark =
        mode == 'dark' ||
        (mode == 'follow' && Theme.of(context).brightness == Brightness.dark);
    final ink = dark ? Colors.white : Colors.black;

    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Material(
            key: const ValueKey('main-dock'),
            color: dark ? Colors.black : Colors.white,
            elevation: 3,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HRadius.pill),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: height(context) * size,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth / 5 < 116 ||
                        MediaQuery.textScalerOf(context).scale(11) > 13;
                    return Row(
                      children: [
                        for (final destination in DockDestination.values)
                          _DockItem(
                            destination: destination,
                            ink: ink,
                            size: size,
                            compact: compact,
                            selected: destination.matches(path),
                            onTap: () => onSelected(destination),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.ink,
    required this.size,
    required this.selected,
    required this.compact,
    required this.onTap,
  });
  final DockDestination destination;
  final Color ink;
  final double size;
  final bool selected, compact;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : HMotion.medium;
    final office = destination == DockDestination.office;
    return Expanded(
      child: Tooltip(
        message: destination.label,
        excludeFromSemantics: true,
        child: Semantics(
          key: ValueKey('dock-${destination.name}'),
          selected: selected,
          button: true,
          label: destination.label,
          onTap: onTap,
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(HRadius.pill),
              child: AnimatedContainer(
                duration: duration,
                curve: HMotion.curve,
                decoration: BoxDecoration(
                  color: selected
                      ? ink.withValues(alpha: .12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(HRadius.pill),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSlide(
                        offset: !reduce && selected
                            ? const Offset(0, -.07)
                            : Offset.zero,
                        duration: duration,
                        curve: HMotion.curve,
                        child: AnimatedScale(
                          scale: !reduce && selected
                              ? (office ? 1.10 : 1.05)
                              : 1,
                          duration: duration,
                          curve: HMotion.curve,
                          child: Icon(
                            destination.icon,
                            color: ink,
                            size: 23 * size,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            office && compact ? 'Office' : destination.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5 * size,
                              height: 1.15,
                              color: ink,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
    transitionDuration: const Duration(milliseconds: 160),
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

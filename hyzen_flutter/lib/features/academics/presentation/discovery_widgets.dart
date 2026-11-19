import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/surfaces.dart';
import '../../content/data/content_providers.dart';
import '../../search/data/search_index.dart';
import '../domain/models.dart';
import 'library_screens.dart';
import '../../../core/widgets/refinement_art.dart';
import '../../../app/safe_nav.dart';

class LibraryShortcuts extends ConsumerWidget {
  const LibraryShortcuts({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final kinds = LibraryKind.values
        .where((k) => ref.watch(sectionEnabledProvider(k.sectionId)))
        .toList();
    return GridView(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            MediaQuery.sizeOf(context).width < 380 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.2
            ? 2
            : 4,
        mainAxisExtent:
            128 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final k in kinds)
          HCard(
            onTap: () => context.push('/study/${k.name}'),
            padding: const EdgeInsets.all(8),
            color: t.brightness == Brightness.light
                ? Color.alphaBlend(
                    kindColor(k).withValues(alpha: .07),
                    Colors.white,
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconBadge(icon: kindIcon(k), color: kindColor(k), size: 42),
                const SizedBox(height: 8),
                Text(
                  k.shortTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: t.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${ref.watch(libraryProvider(k)).valueOrNull?.data.fileCount ?? '…'} files',
                  style: t.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class SubjectDiscovery extends ConsumerWidget {
  const SubjectDiscovery({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = <String>{};
    final subjects = ref
        .watch(searchIndexProvider)
        .where(
          (h) => h.type == HitType.subject && seen.add(h.title.toLowerCase()),
        )
        .take(4)
        .toList();
    if (subjects.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Popular subjects'),
        const SizedBox(height: 12),
        GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: subjects.length,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                MediaQuery.sizeOf(context).width < 350 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.6
                ? 1
                : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent:
                (compact ? 84 : 132) *
                MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
          ),
          itemBuilder: (context, i) {
            if (compact) {
              final h = subjects[i];
              return HCard(
                radius: HRadius.lg,
                padding: const EdgeInsets.all(12),
                onTap: () => context.open(h.route),
                child: Row(
                  children: [
                    const RefinementArt(RefinementGlyph.subject, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Tooltip(
                        message: h.title,
                        child: Text(
                          h.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            final colors = [
              HColors.notes,
              HColors.lectures,
              HColors.info,
              HColors.papers,
            ];
            final h = subjects[i];
            final color = colors[i % 4];
            return HCard(
              onTap: () => context.open(h.route),
              padding: const EdgeInsets.all(14),
              color: Theme.of(context).brightness == Brightness.light
                  ? Color.alphaBlend(color.withValues(alpha: .08), Colors.white)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RefinementArt(RefinementGlyph.subject, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    h.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Notes, MCQs & more',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

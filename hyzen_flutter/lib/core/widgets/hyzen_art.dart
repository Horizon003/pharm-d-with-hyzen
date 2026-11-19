import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class HyzenArt extends StatelessWidget {
  const HyzenArt(this.name, {super.key, this.size = 160});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (name == 'study-kit' || name == 'office-kit') {
      return Image.asset(
        'assets/reference/$name.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: (size * 3).round(),
        excludeFromSemantics: true,
      );
    }
    if (name == 'library' || name == 'downloads' || name == 'downloads-card') {
      final studying = name == 'library';
      final t = Theme.of(context);
      return SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                studying
                    ? 'assets/mascot/mascot_studying.png'
                    : name == 'downloads-card'
                    ? 'assets/mascot/mascot_success_wave.png'
                    : 'assets/mascot/mascot_downloading.png',
                fit: BoxFit.contain,
                cacheWidth: (size * 2).round(),
                semanticLabel: studying
                    ? 'Hyzen panda with a study book'
                    : name == 'downloads-card'
                    ? 'Hyzen panda waving from the offline library card'
                    : 'Hyzen panda with an offline download tablet',
              ),
            ),
            Positioned(
              left: 4,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.colorScheme.outlineVariant),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x16000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    studying ? Icons.menu_book_rounded : Icons.download_rounded,
                    size: 24,
                    color: t.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Image.asset(
      'assets/illustrations/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * 2).round(),
      excludeFromSemantics: true,
    );
  }
}

class HyzenBanner extends StatelessWidget {
  const HyzenBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.art,
    this.eyebrow,
    this.action,
    this.actionLabel,
    this.gradient,
  });
  final String title, subtitle, art;
  final String? eyebrow, actionLabel;
  final VoidCallback? action;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient:
            gradient ??
            (art == 'downloads' || art == 'downloads-card'
                ? const LinearGradient(
                    colors: [Color(0xFFC7DDFD), Color(0xFFAFCDFB)],
                  )
                : hStudyGradient),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final hideArt = MediaQuery.textScalerOf(context).scale(1) > 1.6;
          final artSize = (c.maxWidth * .40).clamp(100.0, 150.0);
          final text = Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              hideArt ? 16 : artSize * .82,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: t.textTheme.labelSmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: c.maxWidth < 350 ? 19 : 21,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: t.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    fontSize: action != null ? 12 : 13,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: action,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            actionLabel ?? 'Explore',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
          return ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: action == null ? (hideArt ? 0 : artSize + 12) : 160,
            ),
            child: Stack(
              children: [
                if (!hideArt)
                  Positioned(
                    right: -3,
                    bottom: 0,
                    child: HyzenArt(art, size: artSize),
                  ),
                text,
              ],
            ),
          );
        },
      ),
    );
  }
}

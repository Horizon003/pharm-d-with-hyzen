import 'dart:async';
import 'workspace_icons.dart';
import 'refinement_art.dart';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'common.dart';
import 'surfaces.dart';
import 'hyzen_art.dart';

IconData documentIconForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf') || lower.contains('pdf')) {
    return Icons.picture_as_pdf_rounded;
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
    return Icons.article_rounded;
  }
  if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
    return Icons.slideshow_rounded;
  }
  if (lower.endsWith('.xls') ||
      lower.endsWith('.xlsx') ||
      lower.endsWith('.csv')) {
    return Icons.table_chart_rounded;
  }
  if (lower.endsWith('.txt') ||
      lower.endsWith('.md') ||
      lower.endsWith('.rtf')) {
    return Icons.text_snippet_rounded;
  }
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp')) {
    return Icons.image_rounded;
  }
  return Icons.description_rounded;
}

Color documentColorForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf') || lower.contains('pdf')) return HColors.error;
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) return HColors.info;
  if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return HColors.special;
  if (lower.endsWith('.xls') ||
      lower.endsWith('.xlsx') ||
      lower.endsWith('.csv')) {
    return HColors.success;
  }
  if (lower.endsWith('.txt') ||
      lower.endsWith('.md') ||
      lower.endsWith('.rtf')) {
    return HColors.ink2;
  }
  return HColors.primary;
}

/// Material list tile used across libraries, downloads, search, settings.
class ResourceTile extends StatelessWidget {
  const ResourceTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.eyebrow,
    this.badge,
    this.compact = false,
    this.leading,
    this.surfaceColor,
  });
  final bool compact;
  final Widget? leading;
  final Color? surfaceColor;
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HCard(
        radius: 24,
        color: surfaceColor,
        shadow: false,
        onTap: onTap,
        semanticLabel: title,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 10 : 12,
        ),
        child: Row(
          children: [
            leading ??
                (icon == Icons.description_rounded
                    ? const RefinementArt(RefinementGlyph.document, size: 40)
                    : (icon == Icons.play_circle_fill_rounded ||
                          icon == Icons.play_circle_rounded ||
                          icon == Icons.video_library_outlined)
                    ? const RefinementArt(RefinementGlyph.lecture, size: 40)
                    : glyphForIcon(icon) != null
                    ? WorkspaceIcon(
                        glyphForIcon(icon)!,
                        size: compact ? 34 : 40,
                      )
                    : IconBadge(
                        icon: icon,
                        color: color,
                        size: compact ? 36 : 42,
                      )),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMarqueeText(
                    title,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall,
                    ),
                  if (eyebrow != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        eyebrow!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.labelSmall,
                      ),
                    ),
                  if (badge != null) ...[const SizedBox(height: 4), badge!],
                ],
              ),
            ),
            const SizedBox(width: 6),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: HColors.ink2,
                ),
          ],
        ),
      ),
    );
  }
}

/// Debounced search field with clear button.
class HSearchField extends StatefulWidget {
  const HSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.autofocus = false,
    this.initial = '',
  });
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;
  final String initial;
  @override
  State<HSearchField> createState() => _HSearchFieldState();
}

class _HSearchFieldState extends State<HSearchField> {
  late final _c = TextEditingController(text: widget.initial);
  Timer? _t;
  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _emit(String v) {
    _t?.cancel();
    _t = Timer(
      const Duration(milliseconds: 250),
      () => widget.onChanged(v.trim()),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: _emit,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _c.clear();
                  _emit('');
                },
              ),
      ),
    );
  }
}

/// Material hero header used at the top of list screens.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.icon,
    this.color = HColors.primary,
    this.stats = const [],
    this.trailing,
  });
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final IconData? icon;
  final Color color;
  final List<(String, String)> stats;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final artwork = icon == Icons.school_rounded
        ? 'library'
        : icon == Icons.download_done_rounded
        ? 'downloads-card'
        : null;
    if (artwork != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyzenBanner(
            title: title,
            subtitle: subtitle ?? '',
            eyebrow: eyebrow,
            art: artwork,
          ),
          if (stats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                stats.map((s) => '${s.$1} ${s.$2}').join(' · '),
                style: t.textTheme.titleMedium?.copyWith(
                  color: t.colorScheme.primary,
                ),
              ),
            ),
        ],
      );
    }
    return HCard(
      radius: HRadius.xl,
      padding: const EdgeInsets.all(HSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Text(
                        eyebrow!,
                        style: t.textTheme.labelSmall?.copyWith(
                          color: adaptiveAccent(context, color),
                          letterSpacing: 0,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(title, style: t.textTheme.headlineSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(subtitle!, style: t.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: HSpace.md),
                Transform.rotate(
                  angle: -0.12,
                  child: IconBadge(icon: icon!, color: color, size: 60),
                ),
              ],
              if (trailing != null) trailing!,
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: HSpace.md),
            Divider(height: 1, color: t.colorScheme.outlineVariant),
            const SizedBox(height: HSpace.sm),
            Wrap(
              spacing: HSpace.lg,
              runSpacing: 6,
              children: [
                for (final s in stats)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: s.$1,
                          style: t.textTheme.titleMedium?.copyWith(
                            color: adaptiveAccent(context, color),
                          ),
                        ),
                        TextSpan(
                          text: '  ${s.$2}',
                          style: t.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Minimal, safe HTML → rich text (p, br, li, strong/b, em/i, headings). No scripts, no links.
class HtmlText extends StatelessWidget {
  const HtmlText(this.html, {super.key, this.style});
  final String html;
  final TextStyle? style;

  static String decode(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&rsquo;', '\u2019')
      .replaceAll('&mdash;', '\u2014');

  static String plain(String html) => decode(
    html.replaceAll(RegExp(r'<[^>]+>'), ' '),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium!;
    var src = html.replaceAll(
      RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      '',
    );
    src = src
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h[1-6])>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\u2022 ')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
    final spans = <TextSpan>[];
    var bold = 0, italic = 0;
    final re = RegExp(r'<(/?)([a-zA-Z0-9]+)[^>]*>');
    var last = 0;
    String clean(String s) => decode(s).replaceAll(RegExp(r'[ \t]+'), ' ');
    for (final m in re.allMatches(src)) {
      if (m.start > last) {
        spans.add(
          TextSpan(
            text: clean(src.substring(last, m.start)),
            style: TextStyle(
              fontWeight: bold > 0 ? FontWeight.w600 : null,
              fontStyle: italic > 0 ? FontStyle.italic : null,
              color: bold > 0 ? Theme.of(context).colorScheme.onSurface : null,
            ),
          ),
        );
      }
      final close = m.group(1) == '/';
      final tag = m.group(2)!.toLowerCase();
      if (tag == 'strong' || tag == 'b' || RegExp(r'^h[1-6]$').hasMatch(tag)) {
        bold += close ? -1 : 1;
      }
      if (tag == 'em' || tag == 'i') italic += close ? -1 : 1;
      if (bold < 0) bold = 0;
      if (italic < 0) italic = 0;
      last = m.end;
    }
    if (last < src.length) {
      spans.add(TextSpan(text: clean(src.substring(last))));
    }
    final text = spans.map((s) => s.text).join().trim();
    if (text.isEmpty) return const SizedBox.shrink();
    // Trim leading/trailing blank lines by collapsing 3+ newlines.
    return Text.rich(
      TextSpan(style: base.copyWith(height: 1.7), children: spans),
      textAlign: TextAlign.start,
    );
  }
}

/// Network image with display-size decoding + graceful fallback.
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.icon = Icons.image_outlined,
  });
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ph = Container(
      width: width,
      height: height,
      color: t.colorScheme.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(icon, color: t.colorScheme.primary),
    );
    final u = url ?? '';
    if (!u.startsWith('http')) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: ph);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        u,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: width == null || !width!.isFinite || width! <= 0
            ? null
            : (width! * dpr).round().clamp(1, 2048),
        cacheHeight: height == null || !height!.isFinite || height! <= 0
            ? null
            : (height! * dpr).round().clamp(1, 2048),
        errorBuilder: (_, __, ___) => ph,
        loadingBuilder: (c, child, p) => p == null ? child : ph,
      ),
    );
  }
}

/// Section title used inside scroll views.
class Gap extends StatelessWidget {
  const Gap(this.h, {super.key});
  final double h;
  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirm',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: HColors.error)
              : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Glass background wrapper for sheets/panels inside scroll views.
class PanelBlock extends StatelessWidget {
  const PanelBlock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HSpace.lg),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) =>
      HCard(radius: HRadius.xl, padding: padding, child: child);
}

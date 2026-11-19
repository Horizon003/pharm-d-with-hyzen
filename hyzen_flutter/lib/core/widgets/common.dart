import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/palettes.dart';
import '../../features/content/data/content_providers.dart';

import '../config/brand.dart';
import '../theme/tokens.dart';
import 'surfaces.dart';
import 'press_feedback.dart';

/// Keeps dense utility rows to one line while gently revealing long titles.
/// Reduced-motion users receive a normal ellipsis instead of autoplaying text.
class HMarqueeText extends StatelessWidget {
  const HMarqueeText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: text,
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}

/// Local brand mark: every square app-logo presentation shares a soft clip.
class HyzenBrandIcon extends StatelessWidget {
  const HyzenBrandIcon({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .24),
    child: Image.asset(
      Brand.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: Brand.appName,
    ),
  );
}

class HyzenLogo extends ConsumerWidget {
  const HyzenLogo({super.key, this.size = 72, this.glow = false});
  final double size;
  final bool glow;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(siteSettingsProvider);
    final id = ref.watch(effectivePaletteProvider);
    final logos = settings.raw['themeLogos'];
    final saved = logos is Map ? logos[id] : null;
    final url = saved == '__default'
        ? ''
        : '${saved ?? (id == 'green' ? settings.logoUrl : '')}';
    Widget fallback() => HyzenBrandIcon(size: size);
    return Semantics(
      label: Brand.appName,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .24),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .14),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: url.startsWith('https://')
            ? ClipRRect(
                borderRadius: BorderRadius.circular(size * .24),
                child: Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  cacheWidth: (size * 3).round(),
                  errorBuilder: (_, __, ___) => fallback(),
                ),
              )
            : fallback(),
      ),
    );
  }
}

/// Primary button with built-in loading state that blocks duplicate taps.
class HButton extends StatelessWidget {
  const HButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedSwitcher(
      duration: HMotion.duration(context),
      child: loading
          ? SizedBox(
              key: const ValueKey('l'),
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: outlined
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Row(
              key: const ValueKey('t'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
    final cb = loading ? null : onPressed;
    return Semantics(
      button: true,
      label: label,
      child: HPressFeedback(
        enabled: cb != null,
        child: outlined
            ? OutlinedButton(onPressed: cb, child: child)
            : FilledButton(onPressed: cb, child: child),
      ),
    );
  }
}

/// Persistent app-style top bar with optional top-left Back.
class HTopBar extends StatelessWidget implements PreferredSizeWidget {
  const HTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final canPop = Navigator.of(context).canPop();
    return SurfacePanel(
      radius: 0,
      tint: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              if (showBack && (canPop || onBack != null))
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                )
              else
                const SizedBox(width: HSpace.screen),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleMedium,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
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
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: t.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: t.colorScheme.primary),
            ),
            const SizedBox(height: HSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: HSpace.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: t.textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[const SizedBox(height: HSpace.lg), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: message,
      message: 'Check your connection and try again.',
      action: SizedBox(
        width: 160,
        child: HButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ),
    );
  }
}

/// Lightweight shimmer-free skeleton (static pulse via opacity only).
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.height = 72,
    this.radius = HRadius.lg,
    this.width,
  });
  final double height;
  final double? width;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.height = 72});
  final int count;
  final double height;
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(HSpace.screen),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: HSpace.sm),
      itemBuilder: (_, __) => Skeleton(height: height),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: t.textTheme.titleLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -.2,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
  });
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: adaptiveAccent(context, color).withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .18 : .11,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: adaptiveAccent(context, color),
        size: size * 0.5,
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: adaptiveAccent(context, color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: adaptiveAccent(context, color)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: adaptiveAccent(context, color),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

void showHSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? HColors.error : null,
      ),
    );
}

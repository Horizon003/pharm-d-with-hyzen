import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/theme/tokens.dart';

/// Approved account geometry, with colors following the existing app theme.
/// Dark constants remain unchanged; light surfaces use the supplied white UI.
abstract final class AccountStyle {
  static const background = HColors.darkBackground;
  static const card = HColors.darkSurface;
  static const raised = HColors.darkSurfaceAlt;
  static const secondary = HColors.darkInk2;
  static const destructive = Color(0xFFFF6053);
  static const link = Color(0xFFB2B2B2);
  static const divider = Color(0xFF493D32);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? background : HColors.background;
  static Color cardOf(BuildContext context, {bool elevated = false}) =>
      isDark(context) ? (elevated ? raised : card) : HColors.surface;
  static Color secondaryOf(BuildContext context) =>
      isDark(context) ? secondary : HColors.ink2;
  static Color linkOf(BuildContext context) =>
      isDark(context) ? link : const Color(0xFF686868);
  static Color avatarOf(BuildContext context) =>
      isDark(context) ? const Color(0xFF322B25) : const Color(0xFFE9DECF);

  static ThemeData theme(BuildContext context) => Theme.of(context);
}

class AccountTheme extends StatelessWidget {
  const AccountTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: hPageGradient),
    child: Theme(data: AccountStyle.theme(context), child: child),
  );
}

class AccountPage extends StatelessWidget {
  const AccountPage({
    super.key,
    required this.title,
    required this.children,
    required this.onBack,
    this.close = false,
    this.onRefresh,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onBack;
  final bool close;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => AccountTheme(
    child: Builder(
      builder: (context) {
        final scroll = ListView(
          key: PageStorageKey('account-$title'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          children: [
            Row(
              children: [
                if (!close) ...[
                  CircularNavigationButton(onPressed: onBack),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: close ? 23 : 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.8,
                    ),
                  ),
                ),
                if (close)
                  CircularNavigationButton(onPressed: onBack, close: true),
              ],
            ),
            SizedBox(height: close ? 20 : 18),
            ...children,
          ],
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value:
              (AccountStyle.isDark(context)
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark)
                  .copyWith(
                    statusBarColor: AccountStyle.backgroundOf(context),
                    systemNavigationBarColor: AccountStyle.backgroundOf(
                      context,
                    ),
                  ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: onRefresh == null
                      ? scroll
                      : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class CircularNavigationButton extends StatelessWidget {
  const CircularNavigationButton({
    super.key,
    required this.onPressed,
    this.close = false,
  });
  final VoidCallback onPressed;
  final bool close;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: Tooltip(
      message: close ? 'Close account' : 'Back',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE8DFF8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4CBDF)),
              ),
              child: Icon(
                close ? Icons.close_rounded : Icons.chevron_left_rounded,
                size: 18,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children, this.raised = false});
  final List<Widget> children;
  final bool raised;
  @override
  Widget build(BuildContext context) => Material(
    color: AccountStyle.cardOf(context, elevated: raised),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: AccountStyle.isDark(context)
          ? BorderSide.none
          : const BorderSide(color: HColors.outline),
    ),
    elevation: 0,
    shadowColor: const Color(0x141C1C1E),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Divider(height: 1, thickness: .7),
            ),
          children[i],
        ],
      ],
    ),
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });
  final String title;
  final String? value, subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Expanded(
              flex: value == null ? 1 : 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: destructive
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AccountStyle.secondaryOf(context),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AccountStyle.secondaryOf(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF77777C),
                size: 25,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.photoUrl,
    required this.fallback,
    this.radius = 28,
  });
  final String? photoUrl;
  final String fallback;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final image = ProfileAvatar.imageFor(photoUrl);
    return CircleAvatar(
      radius: radius,
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, __) {},
      backgroundColor: AccountStyle.avatarOf(context),
      child: Text(
        fallback.isEmpty ? 'H' : fallback[0].toUpperCase(),
        style: TextStyle(
          fontSize: 16,
          color: AccountStyle.secondaryOf(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AccountProfileCard extends StatelessWidget {
  const AccountProfileCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.photoUrl,
    required this.onTap,
    this.badges,
  });
  final Widget? badges;
  final String name, subtitle;
  final String? photoUrl;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SettingsCard(
    raised: true,
    children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AccountAvatar(photoUrl: photoUrl, fallback: name, radius: 28),
                  if (badges != null) badges!,
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AccountStyle.secondaryOf(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF77777C),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class AccountSectionHeader extends StatelessWidget {
  const AccountSectionHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
    child: Text(
      title,
      style: TextStyle(
        color: AccountStyle.secondaryOf(context),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class RoundedPrimaryButton extends StatelessWidget {
  const RoundedPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 36),
      backgroundColor: AccountStyle.isDark(context)
          ? Colors.white
          : HColors.ink,
      foregroundColor: AccountStyle.isDark(context)
          ? Colors.black
          : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      textStyle: Theme.of(context).textTheme.labelLarge,
    ),
    onPressed: loading ? null : onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );
}

class DestructiveActionButton extends StatelessWidget {
  const DestructiveActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SettingsCard(
    children: [
      SettingsRow(
        title: label,
        destructive: true,
        onTap: onPressed,
        trailing: const SizedBox.shrink(),
      ),
    ],
  );
}

/// Controlled switch: the owner persists the value. Keyboard and screen reader
/// activation use the same callback as touch, with a full 60x48 hit target.
class AccountToggle extends StatelessWidget {
  const AccountToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  @override
  Widget build(BuildContext context) {
    void activate() => onChanged?.call(!value);
    return Semantics(
      label: label,
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : activate,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: onChanged != null,
          mouseCursor: onChanged == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                activate();
                return null;
              },
            ),
          },
          child: Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChanged == null ? null : activate,
              child: SizedBox(
                width: 60,
                height: 48,
                child: Center(
                  child: Container(
                    width: 56,
                    height: 34,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AccountStyle.isDark(context)
                          ? AccountStyle.raised
                          : const Color(0xFFE1E1E5),
                      borderRadius: BorderRadius.circular(16),
                      border: Focus.of(context).hasFocus
                          ? Border.all(
                              color: AccountStyle.linkOf(context),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 7,
                          left: value ? 7 : null,
                          right: value ? null : 6,
                          child: value
                              ? SizedBox(
                                  height: 14,
                                  child: VerticalDivider(
                                    width: 3,
                                    thickness: 2,
                                    color: AccountStyle.secondaryOf(context),
                                  ),
                                )
                              : Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AccountStyle.secondaryOf(context),
                                    ),
                                  ),
                                ),
                        ),
                        AnimatedAlign(
                          alignment: value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
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
      ),
    );
  }
}

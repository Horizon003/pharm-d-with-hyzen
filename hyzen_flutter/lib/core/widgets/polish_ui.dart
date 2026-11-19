import 'dart:math' as math;
import 'display_preferences.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class HAssetIcon extends StatelessWidget {
  const HAssetIcon(this.name, {super.key, this.size = 26});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/reference/$name.png',
    width: size * UiDensity.of(context),
    height: size * UiDensity.of(context),
    cacheWidth: (size * 3).ceil(),
    excludeFromSemantics: true,
  );
}

/// Small clipped glass surface, supported by Flutter on Android and iOS.
class HGlassButton extends StatelessWidget {
  const HGlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });
  final String icon, label;
  final VoidCallback onTap;
  final int badge;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      label: label,
      value: badge > 0 ? '$badge unread' : null,
      child: SizedBox.square(
        dimension: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Stack(
              children: [
                Center(
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .65),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xE6FFFFFF),
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: HAssetIcon(icon, size: 19),
                      ),
                    ),
                  ),
                ),
                if (badge > 0)
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: Container(
                      height: 16,
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: ExcludeSemantics(
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
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
  );
}

/// Low-amplitude art motion that follows the route and app lifecycle.
class HSoftArt extends StatefulWidget {
  const HSoftArt({
    super.key,
    required this.child,
    this.loop = false,
    this.enabled = true,
  });
  final Widget child;
  final bool loop;
  final bool enabled;
  @override
  State<HSoftArt> createState() => _HSoftArtState();
}

class _HSoftArtState extends State<HSoftArt>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _started = false;
  late bool _resumed;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    final enabled =
        widget.enabled &&
        _resumed &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (!enabled) {
      _motion.stop();
      _motion.value = 1;
      return;
    }
    if (widget.loop) {
      if (!_motion.isAnimating) {
        _motion.duration = const Duration(milliseconds: 6000);
        _motion.repeat();
      }
    } else if (!_started) {
      _started = true;
      _motion.forward();
    }
  }

  @override
  void didUpdateWidget(covariant HSoftArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loop != widget.loop || oldWidget.enabled != widget.enabled) {
      _motion.stop();
      _started = false;
      _motion.value = widget.enabled ? 0 : 1;
      _syncMotion();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: widget.child,
    builder: (_, child) {
      final wave = widget.loop
          ? math.sin(_motion.value * math.pi * 2) * .6
          : math.sin(_motion.value * math.pi * 4) * (1 - _motion.value);
      return Transform.translate(
        offset: Offset(0, wave * 5),
        child: Transform.rotate(angle: wave * .025, child: child),
      );
    },
  );
}

Future<void> showCardPreview(
  BuildContext context, {
  required String title,
  required String description,
  required String asset,
  required Color color,
  required VoidCallback onOpen,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close card preview',
  barrierColor: Colors.black12,
  transitionDuration: HMotion.duration(context, HMotion.medium),
  transitionBuilder: (context, animation, _, child) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween(
        begin: .96,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
  pageBuilder: (dialog, _, __) => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              key: const ValueKey('card-hold-preview'),
              color: color,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HAssetIcon(asset, size: 58),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close preview',
                          onPressed: () => Navigator.pop(dialog),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: Theme.of(dialog).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: Theme.of(dialog).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(dialog);
                        onOpen();
                      },
                      child: const Text('Open'),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/refinement_art.dart';
import '../content/data/content_providers.dart';
import '../content/domain/site_models.dart';
import '../viewer/document_flow.dart';

class NoticeHost extends ConsumerStatefulWidget {
  const NoticeHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<NoticeHost> createState() => _NoticeHostState();
}

class _NoticeHostState extends ConsumerState<NoticeHost> {
  static final _sessionSeen = <String>{};
  DialogRoute<void>? _route;
  NavigatorState? _navigator;
  Timer? _expiry;
  String? _activeKey;
  GoRouter? _router;
  String _routePath = '';
  int _generation = 0;
  bool _seen(String key) =>
      _sessionSeen.contains(key) ||
      ref.read(sharedPrefsProvider).getBool('hyzen_notice_$key') == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router = ref.read(routerProvider);
      setState(
        () => _routePath = _router!.routeInformationProvider.value.uri.path,
      );
      _router!.routerDelegate.addListener(_routeChanged);
    });
  }

  void _routeChanged() {
    final next = _router?.routerDelegate.currentConfiguration.uri.path ?? '';
    if (!mounted || next == _routePath) return;
    setState(() => _routePath = next);
  }

  void _close() {
    _expiry?.cancel();
    final route = _route;
    _route = null;
    _activeKey = null;
    if (route != null && _navigator?.mounted == true && route.isActive) {
      _navigator!.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _generation++;
    _expiry?.cancel();
    _router?.routerDelegate.removeListener(_routeChanged);
    final route = _route;
    final navigator = _navigator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null && navigator?.mounted == true && route.isActive) {
        navigator!.removeRoute(route);
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final enabled = ref.watch(boolPrefProvider('pref_announcements'));
    final admin = ref.watch(isAdminProvider);
    final notice = ref.watch(siteSettingsProvider).notice;
    final key = uid == null || notice == null ? null : '$uid:${notice.id}';
    final readingDocument =
        ref.watch(documentHandoffProvider) ||
        _routePath.isEmpty ||
        _routePath == '/create-pdf' ||
        _routePath.startsWith('/pdf-studio') ||
        _routePath == '/viewer' ||
        _routePath == '/imported-viewer' ||
        _routePath.startsWith('/pdf-studio/viewer/');
    final valid =
        uid != null &&
        enabled &&
        !admin &&
        !readingDocument &&
        notice != null &&
        notice.eligible(now: DateTime.now(), seen: (_) => _seen(key!));
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      if (_route != null) {
        if (!valid || key != _activeKey) _close();
        return;
      }
      if (!valid || _seen(key!)) return;
      final n = notice;
      final prefs = ref.read(sharedPrefsProvider);
      _navigator = Navigator.of(context, rootNavigator: true);
      late final DialogRoute<void> route;
      route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: n.raw['followTheme'] == false
            ? _color(n.raw['background'], Colors.black).withValues(alpha: .95)
            : Colors.black.withValues(alpha: .45),
        builder: (c) => _NoticeCard(n: n, onClose: () => Navigator.of(c).pop()),
      );
      _route = route;
      _activeKey = key;
      if (n.raw['sound'] == 'chime') {
        unawaited(SystemSound.play(SystemSoundType.click));
      }
      if (n.expires != null) {
        final remaining = n.expires!.difference(DateTime.now());
        _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
          if (mounted && identical(_route, route)) _close();
        });
      }
      unawaited(
        _navigator!.push(route).whenComplete(() {
          _sessionSeen.add(key);
          if (n.repeat != 'session') {
            unawaited(prefs.setBool('hyzen_notice_$key', true));
          }
          if (identical(_route, route)) {
            _expiry?.cancel();
            _route = null;
            _activeKey = null;
          }
        }),
      );
    });
    return widget.child;
  }
}

Color _color(Object? raw, Color fallback) {
  final value = '${raw ?? ''}'.replaceFirst('#', '');
  final number = value.length == 6 ? int.tryParse(value, radix: 16) : null;
  return number == null ? fallback : Color(0xFF000000 | number);
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.n, required this.onClose});
  final FullScreenNotice n;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final custom = n.raw['followTheme'] == false;
    final card = custom
        ? _color(n.raw['card'], theme.colorScheme.surface)
        : theme.colorScheme.surface;
    final ink = custom
        ? _color(n.raw['text'], theme.colorScheme.onSurface)
        : theme.colorScheme.onSurface;
    final accent = custom
        ? _color(n.raw['accent'], theme.colorScheme.primary)
        : theme.colorScheme.primary;
    final buttonInk = custom
        ? _color(n.raw['buttonText'], theme.colorScheme.onPrimary)
        : theme.colorScheme.onPrimary;
    final size = (num.tryParse('${n.raw['fontSize']}') ?? 15)
        .toDouble()
        .clamp(12, 24)
        .toDouble();
    final radius = (num.tryParse('${n.raw['radius']}') ?? 28)
        .toDouble()
        .clamp(0, 48)
        .toDouble();
    final align = n.raw['align'] == 'center'
        ? TextAlign.center
        : TextAlign.left;
    final font = switch (n.raw['font']) {
      'serif' => 'serif',
      'system' => null,
      _ => 'Outfit',
    };
    return Dialog(
      backgroundColor: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: DefaultTextStyle(
            style: TextStyle(
              color: ink,
              fontSize: size,
              fontFamily: font,
              height: 1.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RefinementArt(
                      n.type == 'update'
                          ? RefinementGlyph.subject
                          : RefinementGlyph.announcement,
                      size: 64,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close notice',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                if (n.image.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    label: '${n.raw['imageAlt'] ?? n.title}',
                    image: true,
                    child: NetImage(
                      n.image,
                      height: 180,
                      fit: n.raw['imageFit'] == 'cover'
                          ? BoxFit.cover
                          : BoxFit.contain,
                      radius: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (n.eyebrow.isNotEmpty)
                  Text(
                    n.eyebrow,
                    textAlign: align,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  n.title,
                  textAlign: align,
                  style: TextStyle(
                    color: ink,
                    fontSize: size + 6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ('${n.raw['version'] ?? ''}'.isNotEmpty)
                  Text(
                    '${n.raw['version']}',
                    textAlign: align,
                    style: TextStyle(color: accent),
                  ),
                const SizedBox(height: 12),
                Text(n.body, textAlign: align),
                const SizedBox(height: 20),
                if (n.primaryText.isNotEmpty && n.primaryUrl.isNotEmpty)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: buttonInk,
                    ),
                    onPressed: () {
                      onClose();
                      openLink(context, n.primaryUrl);
                    },
                    child: Text(n.primaryText),
                  ),
                if (n.secondaryText.isNotEmpty && n.secondaryUrl.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: accent),
                    onPressed: () {
                      onClose();
                      openLink(context, n.secondaryUrl);
                    },
                    child: Text(n.secondaryText),
                  ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: accent),
                  onPressed: onClose,
                  child: Text(
                    n.dismissText.isEmpty ? 'Keep studying' : n.dismissText,
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

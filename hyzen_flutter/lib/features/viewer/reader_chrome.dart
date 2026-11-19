import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/workspace_icons.dart';

class ReaderTools {
  VoidCallback? search, zoomIn, zoomOut, pages;
  void run(String action, BuildContext context) {
    final callback = switch (action) {
      'search' => search,
      'pages' => pages,
      'in' => zoomIn,
      _ => zoomOut,
    };
    if (callback != null) {
      callback();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This tool is available after a native PDF opens. Save offline for full PDF tools.',
        ),
      ),
    );
  }
}

class ReaderAction {
  const ReaderAction(
    this.label,
    this.icon,
    this.run, {
    this.group = 'File options',
  });
  final String label, group;
  final IconData icon;
  final VoidCallback run;
}

Future<void> showReaderActions(
  BuildContext context,
  List<ReaderAction> actions,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: const Color(0xFFF0EBFA),
  builder: (c) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i == 0 || actions[i].group != actions[i - 1].group)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text(
                  actions[i].group,
                  style: Theme.of(c).textTheme.titleSmall,
                ),
              ),
            ListTile(
              leading: switch (controlGlyphForIcon(actions[i].icon)) {
                final glyph? => ControlIcon(glyph),
                null => Icon(actions[i].icon),
              },
              title: Text(actions[i].label),
              onTap: () {
                Navigator.pop(c);
                actions[i].run();
              },
            ),
          ],
        ],
      ),
    ),
  ),
);

/// Observes taps without joining the gesture arena, leaving native PDF pinch,
/// scrolling and long-press text selection intact.
class ReaderScaffold extends StatefulWidget {
  const ReaderScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.onShare,
    this.onDownload,
    this.downloadLabel = 'Download',
    this.downloadVerified = false,
    this.banner,
  });
  final String title;
  final Widget child;
  final List<ReaderAction> actions;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final String downloadLabel;
  final bool downloadVerified;
  final Widget? banner;
  @override
  State<ReaderScaffold> createState() => _ReaderScaffoldState();
}

class _ReaderScaffoldState extends State<ReaderScaffold> {
  bool _visible = true, _moved = false;
  final _pointers = <int>{};
  Offset? _down;
  Duration? _time;
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/pdf-studio');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  key: const ValueKey('reader-page-surface'),
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (e) {
                    _pointers.add(e.pointer);
                    if (_pointers.length == 1) {
                      _down = e.position;
                      _time = e.timeStamp;
                      _moved = false;
                    } else {
                      _moved = true;
                    }
                  },
                  onPointerMove: (e) {
                    if (_down != null && (e.position - _down!).distance > 9) {
                      _moved = true;
                    }
                  },
                  onPointerCancel: (e) {
                    _pointers.remove(e.pointer);
                    _moved = true;
                  },
                  onPointerUp: (e) {
                    _pointers.remove(e.pointer);
                    if (!_moved &&
                        _pointers.isEmpty &&
                        _time != null &&
                        e.timeStamp - _time! <
                            const Duration(milliseconds: 220)) {
                      setState(() => _visible = !_visible);
                    }
                  },
                  child: RepaintBoundary(child: widget.child),
                ),
              ),
              if (_visible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xE6F0EBFA), Color(0xE6FFF4E9)],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  _ReaderButton(
                                    label: 'Close preview',
                                    glyph: ControlGlyph.back,
                                    onTap: _back,
                                    showCircle: true,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    height: 48,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned(
                                          left: 2,
                                          right: 2,
                                          child: Container(
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: const Color(0xDDE6E7EA),
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _ReaderButton(
                                              label: 'Share',
                                              glyph: ControlGlyph.share,
                                              onTap: widget.onShare,
                                            ),
                                            _ReaderButton(
                                              label: widget.downloadLabel,
                                              glyph: widget.downloadVerified
                                                  ? null
                                                  : ControlGlyph.download,
                                              icon: widget.downloadVerified
                                                  ? Icons.check_rounded
                                                  : null,
                                              onTap: widget.onDownload,
                                            ),
                                            _ReaderButton(
                                              label: 'File options',
                                              glyph: ControlGlyph.more,
                                              onTap: () => showReaderActions(
                                                context,
                                                widget.actions,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.banner != null) widget.banner!,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderButton extends StatelessWidget {
  const _ReaderButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.glyph,
    this.showCircle = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final ControlGlyph? glyph;
  final bool showCircle;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: SizedBox.square(
      dimension: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: showCircle
                    ? const Color(0xDDE6E7EA)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Opacity(
                  opacity: onTap == null ? .35 : 1,
                  child: glyph != null
                      ? ControlIcon(
                          glyph!,
                          size: 22,
                          color: const Color(0xFF25242A),
                        )
                      : Icon(icon, size: 18, color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

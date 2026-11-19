import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'study_tracker.dart';

/// Only a successfully rendered, visible document owns a study lease. Failed
/// loads, a covered route and background time never become study time.
class DocumentStudyScope extends ConsumerStatefulWidget {
  const DocumentStudyScope({
    super.key,
    required this.ready,
    required this.child,
  });
  final bool ready;
  final Widget child;
  @override
  ConsumerState<DocumentStudyScope> createState() => _DocumentStudyScopeState();
}

class _DocumentStudyScopeState extends ConsumerState<DocumentStudyScope> {
  final Object _owner = Object();
  StudyTracker? _tracker;
  bool _active = false;
  void _update() {
    final visible =
        widget.ready &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        TickerMode.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!visible && !_active) return;
      ProviderContainer container;
      try {
        container = ProviderScope.containerOf(context, listen: false);
      } on StateError {
        return;
      } // Standalone renderers have no signed-in app.
      final tracker = container.read(studyTrackerProvider);
      if (_tracker != tracker && _active) {
        _tracker?.documentClosed(_owner);
        _active = false;
      }
      _tracker = tracker;
      if (visible != _active) {
        _active = visible;
        visible
            ? tracker.documentOpened(_owner)
            : tracker.documentClosed(_owner);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _update();
    return widget.child;
  }

  @override
  void dispose() {
    final tracker = _tracker;
    if (_active) scheduleMicrotask(() => tracker?.documentClosed(_owner));
    super.dispose();
  }
}

import 'dart:js_interop';
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class LectureSurface extends StatefulWidget {
  const LectureSurface({super.key, required this.uri, required this.onReady});
  final Uri uri;
  final VoidCallback onReady;
  @override
  State<LectureSurface> createState() => _LectureSurfaceState();
}

class _LectureSurfaceState extends State<LectureSurface> {
  static int sequence = 0;
  late final String view = 'hyzen-lecture-${sequence++}';
  @override
  void initState() {
    super.initState();
    ui.platformViewRegistry.registerViewFactory(view, (_) {
      final iframe = web.HTMLIFrameElement()
        ..src = widget.uri.toString()
        ..title = 'Lecture video'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
        ..allowFullscreen = true
        ..referrerPolicy = 'strict-origin-when-cross-origin';
      iframe.style
        ..border = '0'
        ..width = '100%'
        ..height = '100%';
      iframe.addEventListener(
        'load',
        ((web.Event _) {
          if (mounted) widget.onReady();
        }).toJS,
      );
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: view);
}

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LectureSurface extends StatefulWidget {
  const LectureSurface({super.key, required this.uri, required this.onReady});
  final Uri uri;
  final VoidCallback onReady;
  @override
  State<LectureSurface> createState() => _LectureSurfaceState();
}

class _LectureSurfaceState extends State<LectureSurface> {
  late final WebViewController controller;
  String? error;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) widget.onReady();
          },
          onWebResourceError: (e) {
            if (mounted && e.isForMainFrame == true) {
              setState(
                () => error =
                    'The player could not load. Check your connection and retry.',
              );
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null ||
                !['https', 'http', 'about'].contains(uri.scheme)) {
              return NavigationDecision.prevent;
            }
            if (request.isMainFrame &&
                uri.host.isNotEmpty &&
                uri.host != 'horizon003.github.io' &&
                !(uri.host == 'www.youtube-nocookie.com' &&
                    uri.path.startsWith('/embed/'))) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _load();
  }

  void _load() {
    final url = widget.uri
        .toString()
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;');
    controller.loadHtmlString(
      '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="strict-origin-when-cross-origin"><style>html,body,iframe{margin:0;width:100%;height:100%;border:0;background:#101014;overflow:hidden}</style></head><body><iframe src="$url" title="Lecture video" referrerpolicy="strict-origin-when-cross-origin" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen" allowfullscreen></iframe></body></html>''',
      baseUrl: 'https://horizon003.github.io/pharm-d-with-hyzen/',
    );
  }

  @override
  Widget build(BuildContext context) => error == null
      ? WebViewWidget(controller: controller)
      : Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!, style: const TextStyle(color: Colors.white)),
                TextButton(
                  onPressed: () {
                    setState(() => error = null);
                    _load();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
}

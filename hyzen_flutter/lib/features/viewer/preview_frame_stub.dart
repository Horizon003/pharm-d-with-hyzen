import '../study_progress/document_study_scope.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'reader_chrome.dart';

/// Android/iOS: isolated WebView ONLY for Google Drive preview (not an app shell).
class PreviewFrame extends StatefulWidget {
  const PreviewFrame({super.key, required this.url, this.tools});
  final String url;
  final ReaderTools? tools;
  @override
  State<PreviewFrame> createState() => _PreviewFrameState();
}

class _PreviewFrameState extends State<PreviewFrame> {
  late final WebViewController _c;
  int _progress = 0;
  bool _error = false;
  bool _loaded = false;
  Timer? _timeout;
  double _zoom = 1;
  void _setZoom(double value) {
    if (!mounted) return;
    _zoom = value.clamp(.5, 4);
    _c.runJavaScript('document.documentElement.style.zoom="$_zoom"');
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 30), () {
      if (mounted && _progress < 100) setState(() => _error = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimeout();
    final allowed = Uri.parse(widget.url).host;
    _c = WebViewController()
      ..enableZoom(true)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            if (mounted && !_error) setState(() => _loaded = true);
            await _c.runJavaScript("""
              (function() {
                var m=document.querySelector('meta[name="viewport"]');
                if(!m){m=document.createElement('meta');m.name='viewport';document.head.appendChild(m);}
                m.content='width=device-width, initial-scale=1, maximum-scale=12, user-scalable=yes';
              })();
            """);
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
            if (p == 100) _timeout?.cancel();
          },
          onHttpError: (e) {
            if (e.request?.uri.toString() == widget.url && mounted) {
              setState(() => _error = true);
            }
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == true && mounted) {
              setState(() => _error = true);
            }
          },
          // Keep the student inside the preview: block "open in Drive"/pop-out navigations.
          onNavigationRequest: (r) {
            final h = Uri.tryParse(r.url)?.host ?? '';
            final ok =
                h == allowed ||
                h.endsWith('.google.com') ||
                h.endsWith('.googleusercontent.com') ||
                h == 'gstatic.com' ||
                h.endsWith('.gstatic.com');
            return ok && !r.url.contains('/view?')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => DocumentStudyScope(
    ready: _loaded && !_error,
    child: _buildPreview(context),
  );

  Widget _buildPreview(BuildContext context) {
    widget.tools?.search = null;
    widget.tools?.pages = null;
    widget.tools?.zoomIn = () => _setZoom(_zoom * 1.25);
    widget.tools?.zoomOut = () => _setZoom(_zoom / 1.25);
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 44),
              const SizedBox(height: 12),
              const Text(
                'Preview couldn’t load. Check your connection or open the original link. Drive files must allow anyone with the link to view.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _error = false);
                  _progress = 0;
                  _startTimeout();
                  _c.reload();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        WebViewWidget(
          controller: _c,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
        if (_progress < 100)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress / 100,
                      minHeight: 5,
                    ),
                    const SizedBox(height: 8),
                    Text('Loading preview · $_progress%'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

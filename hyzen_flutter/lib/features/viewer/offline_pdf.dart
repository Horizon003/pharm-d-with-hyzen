import '../study_progress/document_study_scope.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter/foundation.dart';
import 'document_bytes.dart';
import 'office_document.dart';
import 'reader_chrome.dart';
import '../pdf_studio/presentation/studio_page_thumbnail.dart';
import '../pdf_studio/data/studio_pdf_engine.dart';

/// On-device PDF renderer for saved files (works with no network).
/// Includes a built-in text search so externally opened and saved PDFs share
/// the same basic reading tools.
class _PdfPasswordDialog extends StatefulWidget {
  const _PdfPasswordDialog({required this.retry});
  final bool retry;
  @override
  State<_PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<_PdfPasswordDialog> {
  final _value = TextEditingController();
  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _open() {
    if (_value.text.isNotEmpty) Navigator.pop(context, _value.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('PDF password'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.retry)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('That password did not unlock this PDF. Try again.'),
          ),
        TextField(
          controller: _value,
          obscureText: true,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 128,
          onSubmitted: (_) => _open(),
          decoration: const InputDecoration(labelText: 'Password'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _open, child: const Text('Open PDF')),
    ],
  );
}

class OfflinePdf extends StatefulWidget {
  const OfflinePdf({
    super.key,
    this.path = '',
    this.uri,
    this.headers = const {},
    this.onOnlinePreview,
    this.onTools,
    this.tools,
    this.initialPage = 1,
    this.onOpened,
  });
  final VoidCallback? onOpened;
  final String path;
  final Uri? uri;
  final Map<String, String> headers;
  final VoidCallback? onOnlinePreview;
  final VoidCallback? onTools;
  final ReaderTools? tools;
  final int initialPage;

  @override
  State<OfflinePdf> createState() => _OfflinePdfState();
}

class _OfflinePdfState extends State<OfflinePdf> {
  bool _reportedOpen = false;
  void _opened() {
    if (_reportedOpen) return;
    _reportedOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
        widget.onOpened?.call();
      }
    });
  }

  final _controller = PdfViewerController();
  PdfTextSearcher? _searcher;
  PdfTextSearcher get searcher {
    final existing = _searcher;
    if (existing != null) return existing;
    final created = PdfTextSearcher(_controller);
    created.addListener(_onSearch);
    return _searcher = created;
  }

  final _searchText = TextEditingController();
  Timer? _searchDebounce;
  bool _searchOpen = false;
  int _pages = 0;
  bool _ready = false;
  int _passwordAttempts = 0;

  Future<String?> _password() async {
    if (!mounted) return null;
    final retry = _passwordAttempts++ > 0;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PdfPasswordDialog(retry: retry),
    );
  }

  void _onSearch() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searcher?.removeListener(_onSearch);
    _searcher?.dispose();
    _searchDebounce?.cancel();
    _searchText.dispose();
    super.dispose();
  }

  Future<void> _showPages() async {
    if (!_ready) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .75,
          child: Column(
            children: [
              ListTile(
                title: const Text('Pages'),
                subtitle: Text('$_pages pages'),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisExtent: 180,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _pages,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () {
                      Navigator.pop(c);
                      _controller.goToPage(pageNumber: i + 1);
                    },
                    child: Card(
                      child: Column(
                        children: [
                          Expanded(
                            child: widget.path.isEmpty
                                ? const Icon(
                                    Icons.description_outlined,
                                    size: 40,
                                  )
                                : StudioPageThumbnail(
                                    page: StudioPage(widget.path, i),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('Page ${i + 1}'),
                          ),
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

  @override
  Widget build(BuildContext context) =>
      DocumentStudyScope(ready: _reportedOpen, child: _buildDocument(context));

  Widget _buildDocument(BuildContext context) {
    final path = widget.path;
    if (path.endsWith('.office') ||
        path.endsWith('.legacy') ||
        path.endsWith('.docx') ||
        path.endsWith('.pptx') ||
        path.endsWith('.xlsx') ||
        path.endsWith('.ppt')) {
      return OfficeReader(path: path, onOpened: _opened);
    }
    if (path.endsWith('.txt') ||
        path.endsWith('.md') ||
        path.endsWith('.rtf')) {
      return FutureBuilder(
        future: documentBytes(path),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not read this document.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final text = utf8.decode(snapshot.data!, allowMalformed: true);
          _opened();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: SelectableText(
              text.isEmpty ? 'This document is empty.' : text,
            ),
          );
        },
      );
    }
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp')) {
      return FutureBuilder(
        future: documentBytes(path),
        builder: (context, s) => s.hasData
            ? InteractiveViewer(
                child: Center(
                  child: Image.memory(
                    s.data!,
                    frameBuilder: (_, child, frame, synchronous) {
                      if (frame != null || synchronous) _opened();
                      return child;
                    },
                    errorBuilder: (_, __, ___) => const Text(
                      'This saved image is damaged. Delete it and save again.',
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  s.hasError ? 'Image could not open.' : 'Opening image…',
                ),
              ),
      );
    }
    final theme = Theme.of(context);
    widget.tools?.search = () {
      if (mounted) setState(() => _searchOpen = true);
    };
    widget.tools?.zoomIn = () {
      if (mounted && _ready) _controller.zoomUp();
    };
    widget.tools?.zoomOut = () {
      if (mounted && _ready) _controller.zoomDown();
    };
    widget.tools?.pages = () {
      if (mounted) _showPages();
    };
    final params = PdfViewerParams(
      scaleEnabled: true,
      panEnabled: true,
      maxScale: 12,
      margin: 4,
      maxImageBytesCachedOnMemory: 64 * 1024 * 1024,
      onViewerReady: (document, controller) {
        _opened();
        if (mounted) {
          setState(() {
            _pages = document.pages.length;
            _ready = true;
          });
          final target = widget.initialPage.clamp(1, document.pages.length);
          if (target > 1) {
            controller.goToPage(pageNumber: target.toInt());
          }
        }
      },
      pagePaintCallbacks: [searcher.pageTextMatchPaintCallback],
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      errorBannerBuilder: (c, e, st, document) => Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not open this PDF. Check access and try again.',
                textAlign: TextAlign.center,
              ),
              if (widget.onOnlinePreview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.tonal(
                    onPressed: widget.onOnlinePreview,
                    child: const Text('Online preview'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final viewer = widget.uri == null
        ? PdfViewer.file(
            path,
            controller: _controller,
            params: params,
            passwordProvider: _password,
          )
        : PdfViewer.uri(
            widget.uri!,
            controller: _controller,
            params: params,
            preferRangeAccess: true,
            useProgressiveLoading: true,
            headers: widget.headers,
            passwordProvider: _password,
          );
    return Column(
      children: [
        if (_searchOpen)
          Material(
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                if (_searchOpen)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: TextField(
                        controller: _searchText,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Find text in this PDF',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (query) {
                          _searchDebounce?.cancel();
                          if (query.trim().isNotEmpty) {
                            searcher.startTextSearch(query.trim());
                          }
                        },
                        onChanged: (query) {
                          _searchDebounce?.cancel();
                          if (query.trim().isEmpty) {
                            searcher.resetTextSearch();
                          } else {
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 320),
                              () => searcher.startTextSearch(query.trim()),
                            );
                          }
                        },
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (_searchOpen && searcher.matches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${(searcher.currentIndex ?? 0) + 1}/${searcher.matches.length}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                if (_searchOpen && searcher.isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_searchOpen)
                  IconButton(
                    tooltip: 'Previous match',
                    onPressed: searcher.matches.isEmpty
                        ? null
                        : () => searcher.goToPrevMatch(),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                if (_searchOpen)
                  IconButton(
                    tooltip: 'Next match',
                    onPressed: searcher.matches.isEmpty
                        ? null
                        : () => searcher.goToNextMatch(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                IconButton(
                  tooltip: _searchOpen ? 'Close search' : 'Search PDF',
                  onPressed: () => setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) {
                      _searchText.clear();
                      searcher.resetTextSearch();
                    }
                  }),
                  icon: Icon(
                    _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: viewer),
      ],
    );
  }
}

class OfficeReader extends StatefulWidget {
  final VoidCallback? onOpened;
  const OfficeReader({super.key, required this.path, this.onOpened});
  final String path;
  @override
  State<OfficeReader> createState() => _OfficeReaderState();
}

class _OfficeReaderState extends State<OfficeReader> {
  bool _reportedOpen = false;
  late final pages = documentBytes(
    widget.path,
  ).then((b) => compute(officePages, b));
  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: pages,
    builder: (context, s) {
      if (s.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not read these Office notes. ${s.error}'),
          ),
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      if (!_reportedOpen) {
        _reportedOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
            widget.onOpened?.call();
          }
        });
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: s.data!.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Document text'),
            );
          }
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page $i',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 14),
                  SelectableText(
                    s.data![i - 1].isEmpty
                        ? 'Graphics-only page. Use original preview or a PDF copy.'
                        : s.data![i - 1],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

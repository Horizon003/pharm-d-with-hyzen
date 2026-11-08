import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/media_upload.dart';
import '../../viewer/document_bytes.dart';
import '../../viewer/document_flow.dart';
import '../data/pdf_studio_repository.dart';
import '../data/studio_pdf_engine.dart';
import 'office_ui.dart';
import 'scan_review_canvas.dart';
import 'scan_annotation_sheet.dart';
import 'scan_filter_sheet.dart';

Future<void> showCreatePdf(BuildContext context) async {
  final router = GoRouter.of(context);
  final source = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create PDF', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Scan with camera'),
              subtitle: const Text('Capture and add pages'),
              onTap: () => Navigator.pop(c, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('From gallery images'),
              subtitle: const Text('Select photos, arrange and save'),
              onTap: () => Navigator.pop(c, 'gallery'),
            ),
          ],
        ),
      ),
    ),
  );
  if (source != null) router.push('/create-pdf?source=$source');
}

class ScanPdfScreen extends ConsumerStatefulWidget {
  const ScanPdfScreen({super.key, this.initialAction});
  final String? initialAction;
  @override
  ConsumerState<ScanPdfScreen> createState() => _ScanPdfScreenState();
}

class _ScanPdfScreenState extends ConsumerState<ScanPdfScreen>
    with WidgetsBindingObserver {
  static const _camera = MethodChannel('com.hyzen.pharmd/camera_pages');
  final _name = TextEditingController(
    text: 'Scan ${officeDate(DateTime.now())}',
  );
  static const _full = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
  bool _crop = false;
  List<Offset> _quad = _full;
  String? _original;
  List<String> _pages = [];
  int _selectedPage = 0;
  bool _busy = true;
  String? _error;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    try {
      if (_android) {
        _pages = await _camera.invokeListMethod<String>('recover') ?? [];
      }
    } catch (_) {
      /* The draft is optional on unsupported platforms. */
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (widget.initialAction == 'camera') {
      await _scan();
    } else if (widget.initialAction == 'gallery') {
      await _gallery();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy && _android) {
      _refreshDraft();
    }
  }

  Future<void> _refreshDraft() async {
    try {
      final pages = await _camera.invokeListMethod<String>('recover');
      if (mounted && !_busy && pages != null) {
        setState(() {
          _pages = pages;
          _selectedPage = pages.isEmpty
              ? 0
              : _selectedPage.clamp(0, pages.length - 1);
        });
      }
    } catch (_) {}
  }

  Future<void> _work(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => _error =
              e.message ?? 'Could not prepare this page. Please retry.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not finish. Your pages are still here; please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() => _work(() async {
    try {
      final paths = await const MethodChannel(
        'com.hyzen.pharmd/document_scanner',
      ).invokeListMethod<String>('scan');
      if (mounted && paths != null) {
        setState(() {
          _pages = paths;
          _selectedPage = 0;
        });
      }
    } on MissingPluginException {
      // Older/unsupported platforms keep the explicit basic-camera fallback.
      final paths = await _camera.invokeListMethod<String>('capture');
      if (mounted && paths != null) {
        setState(() {
          _pages = paths;
          _selectedPage = 0;
        });
      }
    }
  });

  bool _confirmingExit = false;
  Future<void> _back() async {
    if (_busy || _confirmingExit) return;
    if (_pages.isNotEmpty || _crop) {
      _confirmingExit = true;
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Save your changes?'),
          content: const Text(
            'Your scanned pages or edits have not been saved yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, 'discard'),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, 'save'),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      _confirmingExit = false;
      if (!mounted || choice == null || choice == 'cancel') return;
      if (choice == 'save') {
        await _finish();
        return;
      }
      if (_android) {
        try {
          await _camera.invokeMethod('clear');
        } catch (_) {
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _pages = [];
        _crop = false;
      });
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/pdf-studio');
    }
  }

  Future<void> _capture() => _work(() async {
    final paths = await _camera.invokeListMethod<String>('capture');
    if (mounted && paths != null) setState(() => _pages = paths);
  });
  Future<void> _gallery() => _work(() async {
    final files = await StudioPdfEngine.pickFiles();
    final paths = files
        .where(
          (f) => RegExp(
            r'\.(jpe?g|png|webp)$',
            caseSensitive: false,
          ).hasMatch(f.path),
        )
        .map((f) => f.path)
        .toList();
    if (files.isNotEmpty && paths.isEmpty) {
      throw PlatformException(
        code: 'images',
        message: 'Choose JPG, PNG or WebP images.',
      );
    }
    if (paths.isEmpty) return;
    final next = _android
        ? await _camera.invokeListMethod<String>('addImages', {'paths': paths})
        : [..._pages, ...paths];
    if (mounted && next != null) {
      setState(() {
        _pages = next;
        _selectedPage = next.isEmpty
            ? 0
            : _selectedPage.clamp(0, next.length - 1);
      });
    }
  });
  Future<void> _replace(List<String> pages) => _work(() async {
    final next = _android
        ? await _camera.invokeListMethod<String>('replace', {'paths': pages})
        : pages;
    if (mounted && next != null) {
      setState(() {
        _pages = next;
        _selectedPage = next.isEmpty
            ? 0
            : _selectedPage.clamp(0, next.length - 1);
      });
    }
  });
  Future<void> _rotate(String path) => _work(() async {
    final next = await _camera.invokeListMethod<String>('rotate', {
      'path': path,
    });
    if (mounted && next != null) {
      setState(() {
        _pages = next;
        _selectedPage = next.isEmpty
            ? 0
            : _selectedPage.clamp(0, next.length - 1);
      });
    }
  });
  Future<void> _save() => _work(() async {
    if (_pages.isEmpty) return;
    final path = await StudioPdfEngine.imagesToPdf(_pages);
    final count = await StudioPdfEngine.pageCount(path);
    if (count != _pages.length) throw const FormatException('Incomplete PDF');
    final name = _cleanFileName(
      _name.text,
    ).replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
    final item = await ref
        .read(pdfStudioHistoryProvider.notifier)
        .importFile(
          path,
          originalFileName: '${name.isEmpty ? 'Scanned notes' : name}.pdf',
          sourceType: 'IMAGE_SCAN',
          operationBadge: 'SCANNED',
        );
    await ref
        .read(pdfStudioHistoryProvider.notifier)
        .updatePageCount(item.id, count);
    if (_android) await _camera.invokeMethod<bool>('clear');
    if (mounted) {
      // The PDF is durable now. Do not let a cancelled/failed share reuse pages
      // whose native draft files have already been cleared.
      setState(() {
        _pages = [];
        _selectedPage = 0;
        _crop = false;
        _busy = false;
      });
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * .72,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                  ),
                  title: Text('Saved ${item.displayName}'),
                  subtitle: Text(
                    '$count page${count == 1 ? '' : 's'} · Office Workspace',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: const Text('Open PDF'),
                  onTap: () => Navigator.pop(sheet, 'open'),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Share PDF'),
                  onTap: () => Navigator.pop(sheet, 'share'),
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt_rounded),
                  title: const Text('Save a copy to device'),
                  onTap: () => Navigator.pop(sheet, 'locate'),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      try {
        if (action == 'share') {
          await MediaUpload.shareDocument(
            item.internalFilePath,
            item.displayName,
            'application/pdf',
          );
        } else if (action == 'locate') {
          await MediaUpload.exportDocument(
            item.internalFilePath,
            item.displayName,
            'application/pdf',
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'PDF saved. Try sharing again from the document menu.',
              ),
            ),
          );
        }
      }
      if (mounted) context.replace('/pdf-studio/viewer/${item.id}');
    }
  });

  String _cleanFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\.+$'), '');
    return cleaned.isEmpty ? 'Scanned notes' : cleaned;
  }

  int get _sel =>
      _pages.isEmpty ? 0 : _selectedPage.clamp(0, _pages.length - 1);

  void _setPages(List<String> next) => setState(() {
    _pages = next;
    _selectedPage = next.isEmpty ? 0 : _selectedPage.clamp(0, next.length - 1);
  });

  /// Replaces the selected page with a fresh capture at the same position.
  Future<void> _retake() async {
    if (_busy || _pages.isEmpty) return;
    final index = _sel;
    final before = [..._pages];
    await _scan();
    if (!mounted) return;
    final added = _pages.where((p) => !before.contains(p)).toList();
    if (added.isEmpty) {
      setState(() => _selectedPage = index);
      return;
    }
    final next = [...before];
    next[index] = added.first;
    next.addAll(added.skip(1));
    await _replace(next);
    if (mounted) setState(() => _selectedPage = index);
  }

  Future<bool> _applyCrop() async {
    if (_pages.isEmpty) return false;
    var success = false;
    await _work(() async {
      final next = await _camera.invokeListMethod<String>('adjust', {
        'paths': [_pages[_sel]],
        'quad': [
          for (final p in _quad) ...[p.dx, p.dy],
        ],
      });
      if (mounted && next != null) {
        _setPages(next);
        setState(() => _crop = false);
        success = true;
      }
    });
    return success;
  }

  Future<void> _toggleCrop() async {
    if (_crop) {
      await _applyCrop();
      return;
    }
    await _work(() async {
      final info = await _camera.invokeMapMethod<String, dynamic>('pageInfo', {
        'path': _pages[_sel],
      });
      final values = (info?['quad'] as List?)?.cast<num>();
      if (!mounted) return;
      setState(() {
        _original = info?['original'] as String? ?? _pages[_sel];
        _quad = values?.length == 8
            ? [
                for (var i = 0; i < 8; i += 2)
                  Offset(values![i].toDouble(), values[i + 1].toDouble()),
              ]
            : _full;
        _crop = true;
      });
    });
  }

  /// Re-detect the ORIGINAL photo and let the user inspect corners before Apply.
  Future<void> _autoDetect() async {
    if (_pages.isEmpty || _busy) return;
    if (!_crop) await _toggleCrop();
    if (!_crop || !mounted) return;
    await _work(() async {
      final quad = await _camera.invokeListMethod<double>('detect', {
        'path': _original,
      });
      if (quad == null || quad.length != 8) {
        throw PlatformException(
          code: 'edges',
          message: 'Edges are unclear. Move each corner onto the page.',
        );
      }
      final points = [
        for (var i = 0; i < 8; i += 2) Offset(quad[i], quad[i + 1]),
      ];
      if (mounted && validCropQuad(points)) setState(() => _quad = points);
    });
  }

  Future<void> _annotate() async {
    if (_busy || _pages.isEmpty) return;
    final path = _pages[_sel];
    final marks = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(builder: (_) => ScanAnnotationScreen(path: path)),
    );
    if (marks == null || marks.isEmpty || !mounted) return;
    await _work(() async {
      final next = await _camera.invokeListMethod<String>('annotate', {
        'path': path,
        'marks': marks,
      });
      if (mounted && next != null) _setPages(next);
    });
  }

  Future<void> _filters() async {
    if (_pages.isEmpty || _busy) return;
    final choice = await showOfficeSheet<ScanFilterChoice>(
      context,
      (_) => ScanFilterSheet(path: _pages[_sel], multiple: _pages.length > 1),
    );
    if (choice == null || !mounted) return;
    final paths = choice.all ? [..._pages] : [_pages[_sel]];
    await _work(() async {
      final next = await _camera.invokeListMethod<String>('adjust', {
        'paths': paths,
        'filter': choice.filter,
        'strength': choice.strength,
        'brightness': choice.brightness,
        'contrast': choice.contrast,
      });
      if (mounted && next != null) _setPages(next);
    });
  }

  Future<void> _pageOptions(int i) async {
    if (_busy || i >= _pages.length) return;
    final action = await showOfficeSheet<String>(
      context,
      (sheet) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          if (_android)
            OfficeSheetItem(
              icon: Icons.cameraswitch_outlined,
              label: 'Retake page',
              onTap: () => Navigator.pop(sheet, 'retake'),
            ),
          if (i > 0)
            OfficeSheetItem(
              icon: Icons.arrow_back_rounded,
              label: 'Move page earlier',
              onTap: () => Navigator.pop(sheet, 'left'),
            ),
          if (i + 1 < _pages.length)
            OfficeSheetItem(
              icon: Icons.arrow_forward_rounded,
              label: 'Move page later',
              onTap: () => Navigator.pop(sheet, 'right'),
            ),
          OfficeSheetItem(
            icon: Icons.rotate_right_rounded,
            label: 'Rotate page',
            onTap: () => Navigator.pop(sheet, 'rotate'),
          ),
          OfficeSheetItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete page ${i + 1}',
            destructive: true,
            onTap: () => Navigator.pop(sheet, 'delete'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'retake':
        setState(() => _selectedPage = i);
        await _retake();
      case 'left' || 'right':
        final to = action == 'left' ? i - 1 : i + 1;
        final next = [..._pages];
        next.insert(to, next.removeAt(i));
        await _replace(next);
        if (mounted) setState(() => _selectedPage = to);
      case 'rotate':
        await _rotate(_pages[i]);
      case 'delete':
        await _replace([..._pages]..removeAt(i));
    }
  }

  Future<void> _finish() async {
    if (_busy || _pages.isEmpty) return;
    if (_crop && !await _applyCrop()) return;
    if (!mounted) return;
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheet).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Save PDF', style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'File name'),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => Navigator.pop(sheet, v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(sheet, _name.text),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (name == null || !mounted) return;
    _name.text = _cleanFileName(name);
    await _save();
  }

  Widget _emptyState(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 64,
            color: OfficeColors.muted(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Add your first page',
            style: TextStyle(
              color: OfficeColors.ink(context),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan a document or choose photos to make a PDF.',
            textAlign: TextAlign.center,
            style: TextStyle(color: OfficeColors.muted(context)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('scan-more'),
            onPressed: _busy ? null : (_android ? _scan : _gallery),
            icon: const Icon(Icons.add),
            label: Text(_android ? 'Scan' : 'Add images'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(documentDraftRevisionProvider, (_, __) {
      if (!_busy) _refreshDraft();
    });
    final count = _pages.length;
    final has = count > 0;
    final sel = _sel;
    final idle = !_busy && has;
    final tools = [
      (
        Icons.crop_rounded,
        'Crop',
        idle && _android ? _toggleCrop : null,
        _crop,
      ),
      (
        Icons.rotate_right_rounded,
        'Rotate',
        idle && !_crop && _android ? () => _rotate(_pages[sel]) : null,
        false,
      ),
      (
        Icons.tune_rounded,
        'Filters',
        idle && !_crop && _android ? _filters : null,
        false,
      ),
      (
        Icons.draw_outlined,
        'Annotate',
        idle && !_crop && _android ? _annotate : null,
        false,
      ),
      (
        Icons.delete_outline_rounded,
        'Delete',
        idle && !_crop ? () => _replace([..._pages]..removeAt(sel)) : null,
        false,
      ),
    ];
    return PopScope(
      canPop: _pages.isEmpty && !_crop && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: OfficeColors.canvas(context),
        appBar: AppBar(
          title: Text(
            _crop ? 'Adjust corners' : 'Review scan',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _busy ? null : _back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: [
            if (MediaQuery.sizeOf(context).width < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) ...[
              IconButton(
                tooltip: 'Add Images',
                onPressed: _busy || _crop ? null : _gallery,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              IconButton(
                key: const ValueKey('save-scan-pdf'),
                tooltip: 'Save PDF',
                onPressed: _busy || !has ? null : _finish,
                icon: const Icon(Icons.save_outlined),
              ),
            ] else ...[
              TextButton(
                onPressed: _busy || _crop ? null : _gallery,
                child: const Text('Add Images'),
              ),
              TextButton(
                key: const ValueKey('save-scan-pdf'),
                onPressed: _busy || !has ? null : _finish,
                child: const Text('Save PDF'),
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 2,
              child: _busy
                  ? const LinearProgressIndicator(
                      minHeight: 2,
                      color: OfficeColors.blue,
                    )
                  : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (_android)
                      TextButton.icon(
                        onPressed: _busy ? null : _capture,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Use basic camera'),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: !has
                  ? _emptyState(context)
                  : GestureDetector(
                      onHorizontalDragEnd: _crop || _busy
                          ? null
                          : (d) {
                              final v = d.primaryVelocity ?? 0;
                              if (v < -80 && sel + 1 < count) {
                                setState(() => _selectedPage = sel + 1);
                              } else if (v > 80 && sel > 0) {
                                setState(() => _selectedPage = sel - 1);
                              }
                            },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                        child: ScanReviewCanvas(
                          key: ValueKey(_pages[sel]),
                          path: _crop
                              ? (_original ?? _pages[sel])
                              : _pages[sel],
                          crop: _crop,
                          quad: _quad,
                          onQuad: (q) {
                            if (!_busy) setState(() => _quad = q);
                          },
                        ),
                      ),
                    ),
            ),
            if (has)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ScanPill(
                  label: 'Auto detect',
                  icon: Icons.grid_on_rounded,
                  onTap: _busy || !_android ? null : _autoDetect,
                ),
              ),
            if (has && !_crop)
              Text(
                'Page ${sel + 1} of $count',
                style: const TextStyle(fontSize: 11),
              ),
            if (has && !_crop)
              ScanThumbStrip(
                pages: _pages,
                onAdd: _busy ? null : (_android ? _scan : _gallery),
                selected: sel,
                onSelect: (i) {
                  if (!_busy) setState(() => _selectedPage = i);
                },
                onOptions: _pageOptions,
                onReorder: (from, to) {
                  if (_busy || from == to) return;
                  final next = [..._pages];
                  next.insert(to, next.removeAt(from));
                  _replace(next);
                  setState(() => _selectedPage = to);
                },
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: OfficeColors.bar(context),
                border: Border(
                  top: BorderSide(color: OfficeColors.divider(context)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final scale =
                              MediaQuery.textScalerOf(context).scale(11) / 11;
                          final width = (constraints.maxWidth / tools.length)
                              .clamp(60.0 * scale, double.infinity);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final t in tools)
                                  SizedBox(
                                    width: width,
                                    child: OfficeToolButton(
                                      icon: t.$1,
                                      label: t.$2,
                                      onTap: t.$3,
                                      selected: t.$4,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_crop)
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _crop = false),
                              child: const Text('Cancel crop'),
                            ),
                            FilledButton(
                              onPressed: _busy ? null : _applyCrop,
                              child: const Text('Apply crop'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScanPageImage extends StatefulWidget {
  const ScanPageImage({super.key, required this.path});
  final String path;
  @override
  State<ScanPageImage> createState() => _ScanPageImageState();
}

class _ScanPageImageState extends State<ScanPageImage> {
  late final Future<Uint8List> _bytes = documentBytes(widget.path);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (_, s) => s.hasData
        ? Image.memory(
            s.data!,
            cacheWidth: 180,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
          )
        : const Icon(Icons.image_outlined),
  );
}

import '../../study_progress/document_study_scope.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/soft_pill_bar.dart';
import '../../../core/widgets/workspace_icons.dart';
import '../data/pdf_studio_repository.dart';
import '../data/studio_file_item.dart';
import '../data/studio_pdf_engine.dart';

enum _MarkTool {
  select,
  arrow,
  note,
  ink,
  highlight,
  underline,
  strike,
  rectangle,
  circle,
  text,
  signature,
}

class StudioAnnotationScreen extends ConsumerStatefulWidget {
  const StudioAnnotationScreen({super.key, required this.file});
  final StudioFileItem file;

  @override
  ConsumerState<StudioAnnotationScreen> createState() =>
      _StudioAnnotationScreenState();
}

class _StudioAnnotationScreenState
    extends ConsumerState<StudioAnnotationScreen> {
  Map<String, List<Map<String, dynamic>>> _all = {};
  ({Uint8List bytes, int width, int height})? _image;
  final _pending = <Offset>[];
  int _page = 1;
  int _total = 0;
  int _color = 0xFF6D35D4;
  double _stroke = 3;
  _MarkTool _tool = _MarkTool.ink;
  bool _working = true;
  int? _selected;
  Offset? _dragPoint;

  void _selectMark(Offset point) {
    _selected = null;
    for (var i = _marks.length - 1; i >= 0; i--) {
      final raw = _marks[i]['points'] as List? ?? const [];
      final points = [
        for (final p in raw)
          if (p is List && p.length == 2)
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];
      if (points.isEmpty) continue;
      final left =
          points.map((p) => p.dx).reduce((a, b) => a < b ? a : b) - .04;
      final top = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b) - .04;
      final right =
          points.map((p) => p.dx).reduce((a, b) => a > b ? a : b) + .15;
      final bottom =
          points.map((p) => p.dy).reduce((a, b) => a > b ? a : b) + .05;
      if (Rect.fromLTRB(left, top, right, bottom).contains(point)) {
        _selected = i;
        break;
      }
    }
  }

  List<Map<String, dynamic>> get _marks => _all.putIfAbsent('$_page', () => []);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        StudioPdfEngine.pageCount(widget.file.internalFilePath),
        StudioPdfEngine.readAnnotations(widget.file.editStateJsonPath),
      ]);
      _all = results[1] as Map<String, List<Map<String, dynamic>>>;
      _total = results[0] as int;
      await _showPage();
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        showHSnack(
          context,
          'Annotation editor could not open: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _showPage() async {
    if (mounted) setState(() => _working = true);
    try {
      _selected = null;
      final result = await StudioPdfEngine.renderPage(
        widget.file.internalFilePath,
        _page - 1,
      );
      if (mounted) {
        setState(() {
          _image = (
            bytes: result.bytes,
            width: result.width,
            height: result.height,
          );
          _pending.clear();
          _working = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        showHSnack(context, 'Page could not render: $e', error: true);
      }
    }
  }

  Future<void> _save() async {
    await StudioPdfEngine.writeAnnotations(widget.file.editStateJsonPath, _all);
    await ref
        .read(pdfStudioHistoryProvider.notifier)
        .markEdited(widget.file.id);
  }

  Future<void> _persist() async {
    try {
      await _save();
    } catch (e) {
      if (mounted) {
        showHSnack(context, 'Could not save page edits: $e', error: true);
      }
    }
  }

  Offset _normalized(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0).toDouble(),
    (point.dy / size.height).clamp(0.0, 1.0).toDouble(),
  );

  void _finishStroke() {
    if (_pending.isEmpty) return;
    if (_marks.length >= 100) {
      setState(() => _pending.clear());
      showHSnack(context, 'This page has reached the edit limit.', error: true);
      return;
    }
    setState(() {
      _marks.add({
        'tool': _tool.name,
        'points': [
          for (final point in _pending) [point.dx, point.dy],
        ],
        'color': _color,
        'stroke': _stroke,
      });
      _pending.clear();
    });
    unawaited(_persist());
  }

  Future<void> _placeText(Offset point) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          _tool == _MarkTool.signature ? 'Typed signature' : 'Page text note',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 90,
          decoration: const InputDecoration(hintText: 'Write on this page'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text),
            child: const Text('Place'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || !mounted) return;
    if (_marks.length >= 100) {
      showHSnack(context, 'This page has reached the edit limit.', error: true);
      return;
    }
    setState(
      () => _marks.add({
        'tool': _tool.name,
        'points': [
          [point.dx, point.dy],
        ],
        'color': _color,
        'stroke': _stroke,
        'text': value.trim(),
      }),
    );
    await _persist();
  }

  Future<void> _export() async {
    setState(() => _working = true);
    try {
      await _save();
      final source = widget.file;
      final pages = [
        for (var index = 0; index < _total; index++)
          StudioPage(
            source.internalFilePath,
            index,
            annotations: _all['${index + 1}'] ?? const [],
          ),
      ];
      final path = await StudioPdfEngine.compose(pages);
      final name = source.displayName.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        ' annotated.pdf',
      );
      final output = await ref
          .read(pdfStudioHistoryProvider.notifier)
          .importFile(
            path,
            originalFileName: name,
            sourceType: 'CREATED',
            operationBadge: 'EDITED',
          );
      if (mounted) {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push('/pdf-studio/viewer/${output.id}');
      }
    } catch (e) {
      if (mounted) {
        showHSnack(context, 'Could not export annotated PDF: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => DocumentStudyScope(
    ready: _image != null && !_working,
    child: _buildEditor(context),
  );

  Widget _buildEditor(BuildContext context) {
    const quickTools = [
      _MarkTool.select,
      _MarkTool.ink,
      _MarkTool.text,
      _MarkTool.signature,
    ];
    final quickToolIndex = quickTools.indexOf(_tool);
    final moreSelected = quickToolIndex < 0;
    final image = _image;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Annotate · ${widget.file.displayName}', maxLines: 1),
        actions: [
          IconButton(
            tooltip: _selected == null
                ? 'Undo last mark'
                : 'Delete selected mark',
            onPressed: _marks.isEmpty
                ? null
                : () {
                    setState(() {
                      if (_selected != null && _selected! < _marks.length) {
                        _marks.removeAt(_selected!);
                        _selected = null;
                      } else {
                        _marks.removeLast();
                      }
                    });
                    unawaited(_persist());
                  },
            icon: _selected == null
                ? const Icon(Icons.undo_rounded)
                : const ControlIcon(ControlGlyph.delete, size: 28),
          ),
          IconButton(
            tooltip: 'Save edit layer',
            onPressed: _working
                ? null
                : () async {
                    try {
                      await _save();
                      if (context.mounted) showHSnack(context, 'Edits saved');
                    } catch (e) {
                      if (context.mounted) {
                        showHSnack(
                          context,
                          'Could not save edits: $e',
                          error: true,
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: SoftPillBar(
          selectedIndex: moreSelected ? quickTools.length : quickToolIndex,
          items: [
            for (final tool in quickTools)
              SoftPillItem(
                label: tool.name,
                icon: WorkspaceIcon(switch (tool) {
                  _MarkTool.signature => WorkspaceGlyph.signature,
                  _MarkTool.text => WorkspaceGlyph.word,
                  _MarkTool.select => WorkspaceGlyph.crop,
                  _ => WorkspaceGlyph.edit,
                }, size: 24),
                onTap: () => setState(() => _tool = tool),
              ),
            SoftPillItem(
              label: 'More edit tools',
              shortLabel: 'More',
              icon: ControlIcon(
                ControlGlyph.more,
                size: 24,
                color: moreSelected ? Colors.white : null,
              ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (sheet) => SafeArea(
                  child: SizedBox(
                    height: MediaQuery.sizeOf(sheet).height * .65,
                    child: ListView(
                      children: [
                        for (final tool in _MarkTool.values)
                          ListTile(
                            title: Text(tool.name),
                            selected: tool == _tool,
                            onTap: () {
                              Navigator.pop(sheet);
                              setState(() => _tool = tool);
                            },
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
      body: Column(
        children: [
          if (_working) const LinearProgressIndicator(),
          if (_tool == _MarkTool.select)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _selected == null
                    ? 'Tap a mark to select it, then drag to move.'
                    : 'Selected · drag to move, or delete using the top button.',
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final color in [
                  0xFF6D35D4,
                  0xFFEF4978,
                  0xFF10886D,
                  0xFFE59A22,
                  0xFF18203B,
                ])
                  IconButton(
                    tooltip: 'Ink color',
                    onPressed: () => setState(() => _color = color),
                    icon: Icon(
                      _color == color ? Icons.circle : Icons.circle_outlined,
                      color: Color(color),
                    ),
                  ),
                const Text('Width'),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _stroke,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() => _stroke = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _working || image == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width =
                          constraints.maxWidth <
                              constraints.maxHeight * image.width / image.height
                          ? constraints.maxWidth
                          : constraints.maxHeight * image.width / image.height;
                      final height = width * image.height / image.width;
                      final size = Size(width, height);
                      return Center(
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart:
                                (_tool == _MarkTool.text ||
                                    _tool == _MarkTool.signature ||
                                    _tool == _MarkTool.note)
                                ? null
                                : (d) {
                                    if (_tool == _MarkTool.select) {
                                      setState(() {
                                        _selectMark(
                                          _normalized(d.localPosition, size),
                                        );
                                        _dragPoint = _normalized(
                                          d.localPosition,
                                          size,
                                        );
                                      });
                                      return;
                                    }
                                    setState(
                                      () => _pending
                                        ..clear()
                                        ..add(
                                          _normalized(d.localPosition, size),
                                        ),
                                    );
                                  },
                            onPanUpdate:
                                (_tool == _MarkTool.text ||
                                    _tool == _MarkTool.signature ||
                                    _tool == _MarkTool.note)
                                ? null
                                : (d) {
                                    final point = _normalized(
                                      d.localPosition,
                                      size,
                                    );
                                    if (_tool == _MarkTool.select) {
                                      if (_selected != null &&
                                          _dragPoint != null) {
                                        final delta = point - _dragPoint!;
                                        setState(() {
                                          final mark =
                                              Map<String, dynamic>.from(
                                                _marks[_selected!],
                                              );
                                          mark['points'] = [
                                            for (final p
                                                in mark['points'] as List)
                                              [
                                                ((p[0] as num).toDouble() +
                                                        delta.dx)
                                                    .clamp(0.0, 1.0),
                                                ((p[1] as num).toDouble() +
                                                        delta.dy)
                                                    .clamp(0.0, 1.0),
                                              ],
                                          ];
                                          _marks[_selected!] = mark;
                                          _dragPoint = point;
                                        });
                                      }
                                      return;
                                    }
                                    setState(() {
                                      if (_tool == _MarkTool.rectangle ||
                                          _tool == _MarkTool.arrow ||
                                          _tool == _MarkTool.circle ||
                                          _tool == _MarkTool.underline ||
                                          _tool == _MarkTool.strike) {
                                        if (_pending.length == 1) {
                                          _pending.add(point);
                                        } else {
                                          _pending[1] = point;
                                        }
                                      } else if (_pending.length < 250 &&
                                          (_pending.isEmpty ||
                                              (point - _pending.last).distance >
                                                  .003)) {
                                        _pending.add(point);
                                      }
                                    });
                                  },
                            onPanEnd: (_) {
                              if (_tool == _MarkTool.select) {
                                unawaited(_persist());
                              } else {
                                _finishStroke();
                              }
                            },
                            onTapDown:
                                (_tool == _MarkTool.text ||
                                    _tool == _MarkTool.signature ||
                                    _tool == _MarkTool.note)
                                ? (details) => _placeText(
                                    _normalized(details.localPosition, size),
                                  )
                                : _tool == _MarkTool.select
                                ? (d) => setState(
                                    () => _selectMark(
                                      _normalized(d.localPosition, size),
                                    ),
                                  )
                                : null,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(image.bytes, fit: BoxFit.fill),
                                CustomPaint(
                                  painter: _MarksPainter(
                                    _marks,
                                    _pending,
                                    _tool,
                                    _color,
                                    _stroke,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _working || _page <= 1
                      ? null
                      : () {
                          _page--;
                          _showPage();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Page $_page / $_total',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _working || _page >= _total
                      ? null
                      : () {
                          _page++;
                          _showPage();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _working ? null : _export,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Export annotated PDF copy'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter(this.marks, this.pending, this.tool, this.color, this.stroke);
  final List<Map<String, dynamic>> marks;
  final List<Offset> pending;
  final _MarkTool tool;
  final int color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in marks) {
      _draw(canvas, size, mark);
    }
    if (pending.isNotEmpty) {
      _draw(canvas, size, {
        'tool': tool.name,
        'points': [
          for (final p in pending) [p.dx, p.dy],
        ],
        'color': color,
        'stroke': stroke,
      });
    }
  }

  void _draw(Canvas canvas, Size size, Map<String, dynamic> mark) {
    final points = <Offset>[];
    for (final raw in mark['points'] as List? ?? const []) {
      if (raw is List && raw.length == 2 && raw[0] is num && raw[1] is num) {
        points.add(
          Offset(
            (raw[0] as num).toDouble() * size.width,
            (raw[1] as num).toDouble() * size.height,
          ),
        );
      }
    }
    if (points.isEmpty) return;
    final type = mark['tool'] as String? ?? 'ink';
    final paint = Paint()
      ..color = Color(
        mark['color'] as int? ?? 0xFF6D35D4,
      ).withValues(alpha: type == 'highlight' ? .36 : 1)
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          (mark['stroke'] as num? ?? 3).toDouble() *
          (type == 'highlight' ? 5 : 1)
      ..strokeCap = StrokeCap.round;
    final first = points.first;
    final last = points.last;
    if (type == 'rectangle' || type == 'circle') {
      final rect = Rect.fromPoints(first, last);
      if (type == 'rectangle') {
        canvas.drawRect(rect, paint);
      } else {
        canvas.drawOval(rect, paint);
      }
    } else if (type == 'text' || type == 'signature' || type == 'note') {
      final tp = TextPainter(
        text: TextSpan(
          text: mark['text'] as String? ?? '',
          style: TextStyle(
            color: paint.color,
            fontSize: type == 'signature' ? 24 : 14,
            fontStyle: type == 'signature'
                ? FontStyle.italic
                : FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - first.dx);
      tp.paint(canvas, first);
    } else {
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      if (type == 'arrow') {
        final angle = math.atan2(last.dy - first.dy, last.dx - first.dx);
        final head = math.max(10.0, paint.strokeWidth * 4);
        canvas.drawLine(
          last,
          last -
              Offset(math.cos(angle - .5) * head, math.sin(angle - .5) * head),
          paint,
        );
        canvas.drawLine(
          last,
          last -
              Offset(math.cos(angle + .5) * head, math.sin(angle + .5) * head),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MarksPainter old) => true;
}

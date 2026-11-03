import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../academics/domain/models.dart';
import '../../downloads/domain/download_record.dart';
import '../../content/data/content_providers.dart';
import '../../shell/app_shell.dart';
import '../../shop/data/shop_controllers.dart';
import '../data/admin_repository.dart';
import '../domain/import_csv.dart';

class AdminContentScreen extends ConsumerStatefulWidget {
  const AdminContentScreen({super.key, required this.kind});
  final LibraryKind kind;
  @override
  ConsumerState<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends ConsumerState<AdminContentScreen> {
  final _path = <String>[];
  final _trail = <String>[];
  bool _busy = false;
  static const _levels = [
    'Professional year',
    'Semester',
    'Subject',
    'Section',
    'Topic',
    'File',
  ];
  int _order(Map<String, dynamic> m) => int.tryParse('${m['order'] ?? 0}') ?? 0;

  Future<void> _apply(
    void Function(List<Map<String, dynamic>> list) action,
  ) async {
    if (_busy) return;
    final path = [..._path];
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .editTree(widget.kind, (tree) => action(childrenAt(tree, path)));
      ref.invalidate(adminTreeProvider(widget.kind));
      await refreshContent(ref, [widget.kind.storageKey]);
      if (mounted) showHSnack(context, 'Content saved');
    } on FriendlyException catch (e) {
      if (mounted) showHSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showHSnack(
          context,
          'Could not save. Check your connection and admin access.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? node]) async {
    final depth = _path.length;
    final name = TextEditingController(text: '${node?[labelKey(depth)] ?? ''}');
    final url = TextEditingController(text: '${node?['pdfUrl'] ?? ''}');
    final form = GlobalKey<FormState>();
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          '${node == null ? 'Add' : 'Edit'} ${_levels[depth].toLowerCase()}',
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  maxLength: 180,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                ),
                if (depth == 5)
                  TextFormField(
                    controller: url,
                    decoration: const InputDecoration(
                      labelText: 'HTTPS file URL',
                    ),
                    validator: (v) {
                      final uri = Uri.tryParse((v ?? '').trim());
                      return uri == null ||
                              uri.scheme != 'https' ||
                              uri.host.isEmpty
                          ? 'Enter a complete HTTPS file URL'
                          : null;
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(c, (name.text.trim(), url.text.trim()));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    url.dispose();
    if (values == null || !mounted) return;
    final id = node == null ? legacyUid('app') : '${node['id']}';
    await _apply((list) {
      final current = list.where((m) => '${m['id']}' == id).firstOrNull;
      if (node != null && current == null) {
        throw FriendlyException(
          'This item was removed. Refresh and try again.',
        );
      }
      if (depth < 5 &&
          list.any(
            (m) =>
                '${m['id']}' != id &&
                '${m[labelKey(depth)] ?? ''}'.trim().toLowerCase() ==
                    values.$1.toLowerCase(),
          )) {
        throw FriendlyException('An item with that name already exists here.');
      }
      final value =
          current ??
          {
            'id': id,
            'order': list.length + 1,
            'published': true,
            if (depth < 5) childKeys[depth]: <Map<String, dynamic>>[],
            if (depth == 5) 'downloads': 0,
          };
      value[labelKey(depth)] = values.$1;
      value['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      if (depth == 5) value['pdfUrl'] = values.$2;
      if (current == null) list.add(value);
    });
  }

  void _preview(Map<String, dynamic> node) {
    final url = '${node['pdfUrl'] ?? ''}'.trim();
    if (url.isEmpty) {
      showHSnack(context, 'This file has no preview link.', error: true);
      return;
    }
    context.push(
      '/viewer',
      extra: FileRef(
        kind: widget.kind,
        title: '${node[labelKey(_path.length)] ?? 'Document'}',
        url: url,
        trail: [..._trail],
      ),
    );
  }

  Future<void> _action(String action, Map<String, dynamic> node) async {
    final id = '${node['id']}';
    if (action == 'edit') return _edit(node);
    if (action == 'preview') return _preview(node);
    final visible = node['published'] != false && node['published'] != 'false';
    if (action == 'delete') {
      if (!await confirmDialog(
        context,
        title: 'Remove this ${_levels[_path.length].toLowerCase()}?',
        message:
            'It and its nested items will be removed from the library. This does not delete the original Drive files.',
        confirm: 'Remove',
        destructive: true,
      )) {
        return;
      }
    }
    if (!mounted) return;
    if (action == 'publish') {
      final publish = !visible;
      if (!await confirmDialog(
        context,
        title: publish ? 'Publish to students?' : 'Hide from students?',
        message: publish
            ? 'This item will become visible in the student library after the server confirms the change.'
            : 'Students will no longer see this item after the server confirms the change. The original Drive file will remain untouched.',
        confirm: publish ? 'Publish' : 'Hide',
      )) {
        return;
      }
    }
    if (!mounted) return;
    await _apply((list) {
      list.sort((a, b) => _order(a).compareTo(_order(b)));
      final index = list.indexWhere((m) => '${m['id']}' == id);
      if (index < 0) {
        throw FriendlyException('This item changed. Refresh and try again.');
      }
      if (action == 'delete') list.removeAt(index);
      if (action == 'publish') list[index]['published'] = !visible;
      if (action == 'up' || action == 'down') {
        final next = index + (action == 'up' ? -1 : 1);
        if (next < 0 || next >= list.length) return;
        final item = list.removeAt(index);
        list.insert(next, item);
      }
      for (var i = 0; i < list.length; i++) {
        list[i]['order'] = i + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isAdminProvider)) {
      return const Scaffold(
        body: EmptyState(icon: Icons.lock_rounded, title: 'Admins only'),
      );
    }
    final async = ref.watch(adminTreeProvider(widget.kind));
    List<Map<String, dynamic>> nodes = [];
    String? error;
    if (async.hasValue) {
      try {
        nodes = childrenAt(async.value!, _path)
          ..sort((a, b) => _order(a).compareTo(_order(b)));
      } on FriendlyException catch (e) {
        error = e.message;
      }
    }
    return TabPage(
      title: 'Manage ${widget.kind.title}',
      subtitle: _levels[_path.length],
      onRefresh: () async {
        ref.invalidate(adminTreeProvider(widget.kind));
        await ref.read(adminTreeProvider(widget.kind).future);
      },
      actions: [
        IconButton(
          tooltip: 'Add ${_levels[_path.length].toLowerCase()}',
          onPressed: _busy ? null : () => _edit(),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
          sliver: SliverList.list(
            children: [
              Wrap(
                spacing: 4,
                children: [
                  ActionChip(
                    label: const Text('Library'),
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _path.clear();
                            _trail.clear();
                          }),
                  ),
                  for (var i = 0; i < _trail.length; i++)
                    ActionChip(
                      label: Text(_trail[i]),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _path.removeRange(i + 1, _path.length);
                              _trail.removeRange(i + 1, _trail.length);
                            }),
                    ),
                ],
              ),
              const Gap(HSpace.md),
              if (_busy) const LinearProgressIndicator(),
              if (async.isLoading) const SkeletonList(),
              if (async.hasError)
                ErrorState(
                  message: 'Could not load this library. Check admin access.',
                  onRetry: () => ref.invalidate(adminTreeProvider(widget.kind)),
                ),
              if (error != null)
                EmptyState(
                  icon: Icons.refresh_rounded,
                  title: error,
                  action: TextButton(
                    onPressed: () => setState(() {
                      _path.clear();
                      _trail.clear();
                    }),
                    child: const Text('Return to library'),
                  ),
                ),
              if (async.hasValue && error == null && nodes.isEmpty)
                EmptyState(
                  icon: Icons.folder_open_rounded,
                  title: 'No items here',
                  action: HButton(
                    label: 'Add ${_levels[_path.length].toLowerCase()}',
                    onPressed: _busy ? null : () => _edit(),
                  ),
                ),
              if (error == null)
                for (final node in nodes)
                  ResourceTile(
                    icon: _path.length == 5
                        ? Icons.picture_as_pdf_outlined
                        : Icons.folder_outlined,
                    color: HColors.primary,
                    title: '${node[labelKey(_path.length)] ?? 'Untitled'}',
                    eyebrow:
                        node['published'] == false ||
                            node['published'] == 'false'
                        ? 'Hidden'
                        : 'Published',
                    subtitle: _path.length == 5
                        ? '${node['pdfUrl'] ?? ''}'
                        : null,
                    onTap: _busy
                        ? null
                        : () {
                            if (_path.length < 5) {
                              setState(() {
                                _trail.add('${node[labelKey(_path.length)]}');
                                _path.add('${node['id']}');
                              });
                            } else {
                              _preview(node);
                            }
                          },
                    trailing: PopupMenuButton<String>(
                      enabled: !_busy,
                      onSelected: (a) => _action(a, node),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (_path.length == 5)
                          const PopupMenuItem(
                            value: 'preview',
                            child: Text('Preview as student'),
                          ),
                        PopupMenuItem(
                          value: 'publish',
                          child: Text(
                            node['published'] == false ||
                                    node['published'] == 'false'
                                ? 'Publish'
                                : 'Hide',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'up',
                          child: Text('Move up'),
                        ),
                        const PopupMenuItem(
                          value: 'down',
                          child: Text('Move down'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Remove',
                            style: TextStyle(color: HColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';

import '../../../core/utils/media_upload.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../downloads/domain/download_record.dart';
import '../../viewer/external_files.dart';
import '../../viewer/offline_pdf.dart';
import '../../viewer/reader_chrome.dart';
import '../data/pdf_studio_repository.dart';
import '../data/studio_file_item.dart';
import 'studio_tools_screen.dart';
import 'office_file_actions.dart';
import 'office_ui.dart';
import '../../shell/app_shell.dart';
import 'studio_export_sheet.dart';
import 'studio_annotation_screen.dart';

enum _StudioFilter { all, starred, scanned, edited, mergedSplit, docs }

class PdfStudioScreen extends ConsumerStatefulWidget {
  const PdfStudioScreen({super.key});

  @override
  ConsumerState<PdfStudioScreen> createState() => _PdfStudioScreenState();
}

class _PdfStudioScreenState extends ConsumerState<PdfStudioScreen> {
  _StudioFilter _filter = _StudioFilter.all;
  String _query = '';

  bool _matches(StudioFileItem file) {
    final filterMatch = switch (_filter) {
      _StudioFilter.all => true,
      _StudioFilter.starred => file.isStarred,
      _StudioFilter.scanned =>
        file.sourceType.contains('SCAN') || file.operationBadge == 'SCANNED',
      _StudioFilter.edited => file.operationBadge == 'EDITED',
      _StudioFilter.mergedSplit =>
        file.operationBadge == 'MERGED' ||
            file.operationBadge == 'SPLIT' ||
            file.operationBadge == 'EXTRACTED',
      _StudioFilter.docs => file.fileCategory == 'DOC',
    };
    return filterMatch &&
        (_query.isEmpty ||
            '${file.displayName} ${file.originalFileName}'
                .toLowerCase()
                .contains(_query.toLowerCase()));
  }

  Future<void> _saveExternal(ExternalDocument file) async {
    try {
      final item = await ref
          .read(pdfStudioHistoryProvider.notifier)
          .importFile(
            file.path,
            originalFileName: file.title,
            sourceType: 'EXTERNAL_INTENT',
            operationBadge: 'IMPORTED',
          );
      await ref
          .read(sharedPrefsProvider)
          .setString('external_studio_${file.id}', item.id);
      if (mounted) {
        showHSnack(context, 'Saved to Office Workspace');
        openStudioReader(context, item);
      }
    } catch (_) {
      if (mounted) {
        showHSnack(
          context,
          'Could not copy this file into Studio.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(pdfStudioHistoryProvider);
    final prefs = ref.watch(sharedPrefsProvider);
    final external = ref.watch(externalHistoryProvider);
    final known = {for (final f in all) f.internalFilePath};
    final knownIds = {for (final f in all) f.id};
    final notImported = external
        .where(
          (d) =>
              !known.contains(d.path) &&
              !knownIds.contains(prefs.getString('external_studio_${d.id}')),
        )
        .toList();
    final rest = all.where(_matches).toList();

    return TabPage(
      title: 'Office Workspace',
      subtitle: 'Scan, edit and organise',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push('/create-pdf?source=camera'),
                    icon: const Icon(Icons.document_scanner_outlined, size: 20),
                    label: const Text('Scan pages'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showOfficeToolsSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Create / import'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (all.isEmpty)
          const SliverToBoxAdapter(child: _EmptyWorkspace()),
        if (all.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'All files',
                style: TextStyle(
                  color: OfficeColors.ink(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _OfficeSearch(
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                children: [
                  for (final f in _StudioFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterPill(
                        label: switch (f) {
                          _StudioFilter.all => 'All',
                          _StudioFilter.starred => 'Starred',
                          _StudioFilter.scanned => 'Scanned',
                          _StudioFilter.edited => 'Edited',
                          _StudioFilter.mergedSplit => 'Combined',
                          _StudioFilter.docs => 'Docs',
                        },
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (rest.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No matching documents',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: OfficeColors.muted(context)),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: rest.length,
              itemBuilder: (_, i) => _FileRow(file: rest[i]),
            ),
        ],
        if (notImported.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Text(
                'Opened with PHARM D WITH HYZEN',
                style: TextStyle(
                  color: OfficeColors.ink(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: notImported.length,
            itemBuilder: (_, i) {
              final d = notImported[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(
                  documentIconForName(d.title),
                  color: OfficeColors.ink(context),
                ),
                title: Text(
                  d.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: OfficeColors.ink(context)),
                ),
                subtitle: Text(
                  'Device file · ${officeRelativeDate(d.openedAt)}',
                  style: TextStyle(color: OfficeColors.muted(context)),
                ),
                trailing: IconButton(
                  tooltip: 'Save to Office Workspace',
                  icon: Icon(
                    Icons.save_alt_rounded,
                    color: OfficeColors.ink(context),
                  ),
                  onPressed: () => _saveExternal(d),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _FileRow extends ConsumerWidget {
  const _FileRow({required this.file});
  final StudioFileItem file;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = OfficeColors.ink(context);
    return InkWell(
      onTap: () => openStudioReader(context, file),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 50,
              child: OfficeFileThumbnail(
                path: file.internalFilePath,
                version: file.updatedAt.toIso8601String(),
                fallbackIcon: documentIconForName(file.displayName),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          file.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (file.isStarred) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: Color(0xFFF5A524),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      officeRelativeDate(file.lastOpenedAt ?? file.updatedAt),
                      formatBytes(file.fileSizeBytes),
                      if (file.pageCount > 0)
                        '${file.pageCount} page${file.pageCount == 1 ? '' : 's'}',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: OfficeColors.muted(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Document actions',
              icon: Icon(Icons.more_vert_rounded, color: ink),
              onPressed: () => showOfficeFileMore(context, ref, file),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficeSearch extends StatelessWidget {
  const _OfficeSearch({required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    style: TextStyle(color: OfficeColors.ink(context)),
    decoration: InputDecoration(
      hintText: 'Search documents',
      hintStyle: TextStyle(color: OfficeColors.muted(context)),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: OfficeColors.muted(context),
      ),
      filled: true,
      fillColor: OfficeColors.page(context),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: OfficeColors.divider(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: OfficeColors.divider(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: OfficeColors.blue, width: 1.6),
      ),
    ),
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? OfficeColors.ink(context) : OfficeColors.page(context),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? OfficeColors.ink(context)
              : OfficeColors.divider(context),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? OfficeColors.page(context)
                    : OfficeColors.ink(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 12),
    child: Column(
      children: [
        Icon(
          Icons.description_outlined,
          size: 64,
          color: OfficeColors.muted(context),
        ),
        const SizedBox(height: 16),
        Text(
          'No recent documents',
          style: TextStyle(
            color: OfficeColors.ink(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Scan pages, convert photos or open a PDF to start.',
          textAlign: TextAlign.center,
          style: TextStyle(color: OfficeColors.muted(context)),
        ),
      ],
    ),
  );
}

class PdfStudioFileViewerScreen extends ConsumerStatefulWidget {
  const PdfStudioFileViewerScreen({
    super.key,
    required this.fileId,
    this.initialPage = 1,
  });
  final String fileId;
  final int initialPage;

  @override
  ConsumerState<PdfStudioFileViewerScreen> createState() =>
      _PdfStudioFileViewerScreenState();
}

class _PdfStudioFileViewerScreenState
    extends ConsumerState<PdfStudioFileViewerScreen> {
  bool _recorded = false;
  final _tools = ReaderTools();

  void _tool(StudioTool tool, StudioFileItem file) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => StudioToolsScreen(tool: tool, initialFile: file),
        ),
      );

  Future<void> _rename(StudioFileItem file) async {
    final value = TextEditingController(text: file.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: value, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, value.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    value.dispose();
    if (name != null) {
      await ref.read(pdfStudioHistoryProvider.notifier).rename(file.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(pdfStudioHistoryProvider);
    StudioFileItem? found;
    for (final item in files) {
      if (item.id == widget.fileId) found = item;
    }
    if (found == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Office Workspace')),
        body: const EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Document not found',
          message: 'It may have been deleted from the workspace.',
        ),
      );
    }
    final active = found;
    if (!_recorded) {
      _recorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(studyTrackerProvider).start();
          ref.read(pdfStudioHistoryProvider.notifier).recordOpen(active.id);
        }
      });
    }
    void edit() => Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => StudioAnnotationScreen(file: active),
      ),
    );
    void export() => showStudioExportSheet(context, active);
    return ReaderScaffold(
      title: active.displayName,
      onShare: () async {
        try {
          await MediaUpload.shareDocument(
            active.internalFilePath,
            active.displayName,
            studioMime(active.internalFilePath),
          );
        } catch (_) {
          if (context.mounted) {
            showHSnack(context, 'Could not share this file.', error: true);
          }
        }
      },
      actions: [
        ReaderAction(
          active.isStarred ? 'Remove bookmark' : 'Bookmark',
          Icons.bookmark_border_rounded,
          () => ref
              .read(pdfStudioHistoryProvider.notifier)
              .setStarred(active.id, !active.isStarred),
        ),
        ReaderAction('Save As', Icons.save_alt_rounded, export),
        ReaderAction(
          'Pages view',
          Icons.grid_view_rounded,
          () => _tools.run('pages', context),
        ),
        ReaderAction(
          'Search',
          Icons.search_rounded,
          () => _tools.run('search', context),
        ),
        ReaderAction(
          'Rename',
          Icons.drive_file_rename_outline_rounded,
          () => _rename(active),
        ),
        if (active.fileCategory == 'PDF') ...[
          ReaderAction(
            'Edit / highlight',
            Icons.edit_outlined,
            edit,
            group: 'File actions',
          ),
          ReaderAction(
            'Convert / export',
            Icons.description_outlined,
            export,
            group: 'File actions',
          ),
          ReaderAction(
            'Merge PDFs',
            Icons.merge_type_rounded,
            () => _tool(StudioTool.merge, active),
            group: 'File actions',
          ),
          ReaderAction(
            'Sign',
            Icons.draw_outlined,
            edit,
            group: 'File actions',
          ),
          ReaderAction(
            'Extract from PDF',
            Icons.call_split_rounded,
            () => _tool(StudioTool.extract, active),
            group: 'File actions',
          ),
          ReaderAction(
            'Organize / rotate pages',
            Icons.rotate_right_rounded,
            () => _tool(StudioTool.organize, active),
            group: 'Quick edits',
          ),
          ReaderAction(
            'Add Note',
            Icons.note_add_outlined,
            edit,
            group: 'Quick edits',
          ),
        ],
        ReaderAction(
          'Zoom in',
          Icons.zoom_in_rounded,
          () => _tools.run('in', context),
          group: 'View',
        ),
        ReaderAction(
          'Zoom out',
          Icons.zoom_out_rounded,
          () => _tools.run('out', context),
          group: 'View',
        ),
        ReaderAction(
          'Send Feedback',
          Icons.feedback_outlined,
          () => context.push('/contact'),
          group: 'Support',
        ),
      ],
      child: OfflinePdf(
        path: active.internalFilePath,
        tools: _tools,
        initialPage: widget.initialPage,
      ),
    );
  }
}

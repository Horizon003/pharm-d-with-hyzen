import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/widgets/common.dart';
import '../academics/domain/drive.dart';
import '../downloads/data/downloads_controller.dart';
import '../downloads/domain/download_record.dart';
import '../home/data/recent_controller.dart';
import 'offline_pdf.dart';
import 'native_preview.dart';
import 'reader_chrome.dart';
import '../../core/utils/links.dart';
import '../../core/utils/media_upload.dart';
import '../../app/providers.dart';
import '../pdf_studio/data/pdf_studio_repository.dart';
import '../pdf_studio/data/studio_file_item.dart';
import '../pdf_studio/presentation/studio_tools_screen.dart';

String _savedName(FileRef file, String path) {
  var extension = path.split('.').last.toLowerCase();
  if (extension == 'office' || extension == 'legacy') {
    extension = file.title.contains('.') ? file.title.split('.').last : 'bin';
  }
  final base = file.title.replaceFirst(RegExp(r'\.[^.]+$'), '');
  return '$base.$extension';
}

String _savedMime(String path) => switch (path.split('.').last.toLowerCase()) {
  'pdf' => 'application/pdf',
  'png' => 'image/png',
  'jpg' || 'jpeg' => 'image/jpeg',
  'webp' => 'image/webp',
  _ => 'application/octet-stream',
};

/// Document viewer. Native chrome, Back top-left, NO "Open original".
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, required this.file});
  final FileRef? file;
  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  bool _preferOnline = false;
  bool _copying = false;
  final _tools = ReaderTools();

  Future<StudioFileItem?> _workingCopy(
    FileRef file,
    DownloadRecord record,
  ) async {
    if (_copying) return null;
    setState(() => _copying = true);
    try {
      final path = record.localPath!;
      final hash = await const MethodChannel(
        'com.hyzen.pharmd/external_files',
      ).invokeMethod<String>('fingerprint', {'path': path});
      if (hash == null || hash.isEmpty) {
        throw const FormatException('File unavailable');
      }
      final prefs = ref.read(sharedPrefsProvider);
      final linked = prefs.getString('external_studio_$hash');
      for (final item in ref.read(pdfStudioHistoryProvider)) {
        if (item.id == linked &&
            await ref
                .read(studioStorageProvider)
                .exists(item.internalFilePath)) {
          return item;
        }
      }
      final item = await ref
          .read(pdfStudioHistoryProvider.notifier)
          .importFile(
            path,
            originalFileName: _savedName(file, path),
            sourceType: 'ACADEMIC_COPY',
            operationBadge: 'IMPORTED',
          );
      await prefs.setString('external_studio_$hash', item.id);
      return item;
    } catch (_) {
      if (mounted) {
        showHSnack(
          context,
          'Could not prepare an editable copy. Please retry.',
          error: true,
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _editCopy(
    FileRef file,
    DownloadRecord record, [
    StudioTool? tool,
  ]) async {
    final item = await _workingCopy(file, record);
    if (!mounted || item == null) return;
    if (tool == null) {
      context.push('/pdf-studio/viewer/${item.id}');
    } else {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => StudioToolsScreen(tool: tool, initialFile: item),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final f = widget.file;
    if (f != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(studyTrackerProvider).start();
        ref.read(recentProvider.notifier).touch(f);
      });
    }
  }

  Future<void> _save(FileRef f) async {
    try {
      await ref.read(downloadsProvider.notifier).save(f);
      if (mounted) {
        showHSnack(context, 'Saved offline \u2014 find it in Downloads');
      }
    } on FriendlyException catch (e) {
      if (mounted) showHSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showHSnack(
          context,
          'Could not save this file. Please retry.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    if (f == null) {
      return Scaffold(
        appBar: const HTopBar(title: 'Document'),
        body: EmptyState(
          icon: Icons.description_outlined,
          title: 'Nothing to show',
          action: HButton(
            label: 'Go home',
            onPressed: () => context.go('/home'),
          ),
        ),
      );
    }
    final rec = ref.watch(downloadForUrlProvider(f.url));
    final ready = rec?.isReady == true && !kIsWeb;
    final showOffline = ready && !_preferOnline;
    final downloading = rec?.status == DownloadStatus.downloading;
    return ReaderScaffold(
      title: f.title,
      onShare: ready
          ? () => MediaUpload.shareDocument(
              rec!.localPath!,
              _savedName(f, rec.localPath!),
              _savedMime(rec.localPath!),
            )
          : null,
      onDownload: ready || downloading ? null : () => _save(f),
      downloadLabel: ready
          ? 'Downloaded'
          : downloading
          ? 'Downloading'
          : 'Download',
      downloadVerified: ready,
      actions: [
        if (!kIsWeb)
          ReaderAction(
            ready
                ? 'Saved offline'
                : downloading
                ? 'Downloading…'
                : 'Save offline',
            ready ? Icons.offline_pin_rounded : Icons.download_rounded,
            () {
              if (!ready && !downloading) _save(f);
            },
          ),
        if (downloading)
          ReaderAction(
            'Pause download',
            Icons.pause_rounded,
            () => ref
                .read(downloadsProvider.notifier)
                .cancel(DriveLinks.offlineKey(f.url)),
          ),
        if (ready) ...[
          ReaderAction(
            'Save As',
            Icons.save_alt_rounded,
            () => MediaUpload.exportDocument(
              rec!.localPath!,
              _savedName(f, rec.localPath!),
              _savedMime(rec.localPath!),
            ),
          ),
          ReaderAction(
            'Read offline',
            Icons.offline_pin_rounded,
            () => setState(() => _preferOnline = false),
          ),
        ],
        ReaderAction(
          'Pages view',
          Icons.grid_view_rounded,
          () => _tools.run('pages', context),
        ),
        ReaderAction(
          'Search PDF',
          Icons.search_rounded,
          () => _tools.run('search', context),
        ),
        ReaderAction(
          'Zoom in',
          Icons.zoom_in_rounded,
          () => _tools.run('in', context),
        ),
        ReaderAction(
          'Zoom out',
          Icons.zoom_out_rounded,
          () => _tools.run('out', context),
        ),
        ReaderAction(
          'Open in browser',
          Icons.open_in_new_rounded,
          () => openLink(context, f.url),
        ),
        if (ready && rec!.localPath!.toLowerCase().endsWith('.pdf')) ...[
          ReaderAction(
            'Edit a copy / PDF tools',
            Icons.edit_outlined,
            () => _editCopy(f, rec),
            group: 'File actions',
          ),
          ReaderAction(
            'Merge PDFs',
            Icons.merge_type_rounded,
            () => _editCopy(f, rec, StudioTool.merge),
            group: 'File actions',
          ),
          ReaderAction(
            'Extract from PDF',
            Icons.call_split_rounded,
            () => _editCopy(f, rec, StudioTool.extract),
            group: 'File actions',
          ),
          ReaderAction(
            'Organize / rotate pages',
            Icons.rotate_right_rounded,
            () => _editCopy(f, rec, StudioTool.organize),
            group: 'Quick edits',
          ),
        ],
      ],
      banner: _copying
          ? const LinearProgressIndicator(minHeight: 2)
          : downloading
          ? LinearProgressIndicator(
              value: rec!.progress > 0 ? rec.progress : null,
              minHeight: 2,
            )
          : null,
      child: showOffline
          ? OfflinePdf(
              key: ValueKey('${rec!.key}:${rec.savedAt}:${rec.localPath}'),
              path: rec.localPath!,
              tools: _tools,
              onOpened: () => ref
                  .read(downloadsProvider.notifier)
                  .markOpened(
                    rec.key,
                    path: rec.localPath!,
                    savedAt: rec.savedAt,
                  ),
            )
          : NativePreview(key: ValueKey(f.url), url: f.url, tools: _tools),
    );
  }
}

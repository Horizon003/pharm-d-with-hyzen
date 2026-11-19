import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/hyzen_art.dart';
import '../../academics/domain/models.dart';
import '../../academics/presentation/library_screens.dart';
import '../../shell/app_shell.dart';
import '../data/downloads_controller.dart';
import '../domain/download_record.dart';
import '../../viewer/external_files.dart';

enum _Sort { newest, name, size }

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});
  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  LibraryKind? _kind;
  String _q = '';
  _Sort _sort = _Sort.newest;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(downloadsProvider).values.toList();
    final opened = ref
        .watch(externalHistoryProvider)
        .where(
          (item) =>
              _q.isEmpty || item.title.toLowerCase().contains(_q.toLowerCase()),
        )
        .toList();
    final used = all.where((r) => r.isReady).fold(0, (s, r) => s + r.sizeBytes);
    var list = all
        .where(
          (r) =>
              (_kind == null || r.kind == _kind) &&
              (_q.isEmpty ||
                  '${r.title} ${r.subtitle}'.toLowerCase().contains(
                    _q.toLowerCase(),
                  )),
        )
        .toList();
    list.sort(
      (a, b) => switch (_sort) {
        _Sort.newest => (b.savedAt ?? DateTime(2100)).compareTo(
          a.savedAt ?? DateTime(2100),
        ),
        _Sort.name => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        _Sort.size => b.sizeBytes.compareTo(a.sizeBytes),
      },
    );
    final t = Theme.of(context);
    return TabPage(
      title: 'Downloads',
      subtitle: 'Read anywhere, even offline',
      actions: [
        PopupMenuButton<_Sort>(
          tooltip: 'Sort',
          icon: const Icon(Icons.sort_rounded),
          initialValue: _sort,
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _Sort.newest, child: Text('Newest first')),
            PopupMenuItem(value: _Sort.name, child: Text('Name A\u2013Z')),
            PopupMenuItem(value: _Sort.size, child: Text('Largest first')),
          ],
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
          sliver: SliverList.list(
            children: [
              HyzenBanner(
                title: 'Your offline library',
                subtitle:
                    '${all.where((r) => r.isReady).length} saved files · ${formatBytes(used)}',
                art: 'downloads',
              ),
              const SizedBox(height: 10),
              if (kIsWeb)
                Text(
                  'Offline downloads are available in the Android app.',
                  style: t.textTheme.bodySmall,
                ),
              const Gap(HSpace.md),
              HSearchField(
                hint: 'Search downloads',
                onChanged: (v) => setState(() => _q = v),
              ),
              const Gap(HSpace.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final k in [null, ...LibraryKind.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(k == null ? 'All' : k.shortTitle),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                      ),
                  ],
                ),
              ),
              const Gap(HSpace.md),
              if (list.isEmpty && all.isEmpty) ...[
                EmptyState(
                  icon: Icons.cloud_download_outlined,
                  title: 'No downloads yet',
                  message: 'Open any file and tap “Save offline”.',
                  action: HButton(
                    label: 'Browse library',
                    onPressed: () => context.go('/study'),
                  ),
                ),
              ],
              if (list.isEmpty && all.isNotEmpty)
                EmptyState(
                  icon: Icons.cloud_download_outlined,
                  title: 'No matches',
                ),
              for (final r in list) _DownloadRow(r: r),
              if (opened.isNotEmpty) ...[
                const Gap(HSpace.lg),
                Text(
                  'Opened with PHARM D WITH HYZEN',
                  style: t.textTheme.titleMedium,
                ),
                Text(
                  'Files from WhatsApp or your phone stay here for offline reading.',
                  style: t.textTheme.bodySmall,
                ),
                const Gap(HSpace.sm),
                for (final item in opened)
                  ResourceTile(
                    icon: Icons.picture_as_pdf_outlined,
                    color: t.colorScheme.primary,
                    title: item.title,
                    subtitle:
                        'Opened ${item.openedAt.toLocal().toString().split('.').first}',
                    onTap: () {
                      final updated = ExternalDocument(
                        item.id,
                        item.title,
                        item.path,
                        DateTime.now(),
                      );
                      ref.read(externalHistoryProvider.notifier).add(updated);
                      context.push('/imported-viewer', extra: updated);
                    },
                    trailing: IconButton(
                      tooltip: 'Delete imported file',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (await confirmDialog(
                          context,
                          title: 'Delete this file?',
                          message:
                              'This removes PHARM D WITH HYZEN’s local copy of “${item.title}”.',
                          confirm: 'Delete',
                          destructive: true,
                        )) {
                          await ref
                              .read(externalHistoryProvider.notifier)
                              .delete(item);
                        }
                      },
                    ),
                  ),
              ],
              if (all.isNotEmpty) ...[
                const Gap(HSpace.md),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: HColors.error),
                  onPressed: () async {
                    if (await confirmDialog(
                      context,
                      title: 'Delete all downloads?',
                      message:
                          'Local copies are removed from this phone. Original files are not affected.',
                      confirm: 'Delete all',
                      destructive: true,
                    )) {
                      await ref.read(downloadsProvider.notifier).removeAll();
                    }
                  },
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: Text(
                    'Delete all local copies',
                    style: t.textTheme.labelLarge?.copyWith(
                      color: HColors.error,
                    ),
                  ),
                ),
              ],
              if (opened.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    if (await confirmDialog(
                      context,
                      title: 'Clear reader history?',
                      message:
                          'Imported local files will be removed from PHARM D WITH HYZEN.',
                      confirm: 'Clear history',
                      destructive: true,
                    )) {
                      for (final item in List<ExternalDocument>.from(
                        ref.read(externalHistoryProvider),
                      )) {
                        await ref
                            .read(externalHistoryProvider.notifier)
                            .delete(item);
                      }
                    }
                  },
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Clear reader history'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.r});
  final DownloadRecord r;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = FileRef(
      kind: r.kind,
      title: r.title,
      url: r.sourceUrl,
      trail: r.trail,
    );
    final downloading = r.status == DownloadStatus.downloading;
    Future<void> resume() async {
      try {
        await ref.read(downloadsProvider.notifier).save(file);
      } catch (e) {
        if (context.mounted) showHSnack(context, '$e', error: true);
      }
    }

    return ResourceTile(
      icon: kindIcon(r.kind),
      color: kindColor(r.kind),
      title: r.title,
      subtitle: r.isReady
          ? '${r.kind.shortTitle} · ${formatBytes(r.sizeBytes)}'
          : r.transferDetail,
      badge: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (downloading) ...[
            LinearProgressIndicator(
              value: r.progress > 0 ? r.progress : null,
              minHeight: 5,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            r.isReady
                ? 'Downloaded · Offline'
                : downloading
                ? 'Downloading ${r.progress > 0 ? '${(r.progress * 100).round()}%' : ''}'
                : r.status == DownloadStatus.paused
                ? 'Paused · tap to resume'
                : 'Interrupted · tap to retry',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: r.isReady
                  ? HColors.success
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      onTap: r.isReady
          ? () => context.push('/viewer', extra: file)
          : downloading
          ? null
          : resume,
      trailing: PopupMenuButton<String>(
        tooltip: 'Download options',
        icon: const Icon(Icons.more_vert_rounded),
        itemBuilder: (_) => [
          if (downloading)
            const PopupMenuItem(value: 'pause', child: Text('Pause')),
          if (!downloading && !r.isReady)
            const PopupMenuItem(value: 'resume', child: Text('Resume / retry')),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete local copy'),
          ),
        ],
        onSelected: (value) async {
          if (value == 'pause') {
            ref.read(downloadsProvider.notifier).cancel(r.key);
            return;
          }
          if (value == 'resume') {
            await resume();
            return;
          }
          if (await confirmDialog(
            context,
            title: 'Delete local copy?',
            message: 'This only removes the copy on this device.',
            confirm: 'Delete',
            destructive: true,
          )) {
            await ref.read(downloadsProvider.notifier).remove(r.key);
            if (context.mounted) showHSnack(context, 'Local copy deleted');
          }
        },
      ),
    );
  }
}

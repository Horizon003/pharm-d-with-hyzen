import '../data/data_files.dart';
import '../domain/import_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../academics/domain/models.dart';
import '../../content/data/content_providers.dart';
import '../../shell/app_shell.dart';
import '../data/admin_repository.dart';
import '../data/csv_files.dart';
import '../domain/import_csv.dart';

class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});
  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  List<SelectedCsv> _files = [];
  ImportPreview? _preview;
  int _added = 0, _skipped = 0;
  bool _busy = false;
  String? _error;
  String _defaultType = 'auto';

  Future<void> _template([String format = 'csv']) async {
    try {
      final saved = format == 'xlsx'
          ? await saveDataBytes(
              'hyzen_import_template.xlsx',
              importTemplateXlsx(),
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            )
          : await saveDataText(
              'hyzen_import_template.$format',
              format == 'json' ? importTemplateJson() : importTemplateCsv(),
              format == 'json' ? 'application/json' : 'text/csv',
            );
      if (mounted && saved) {
        showHSnack(context, '${format.toUpperCase()} template saved');
      }
    } on MissingPluginException {
      if (mounted) {
        showHSnack(
          context,
          'File saving is available in the Android app and web version.',
          error: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showHSnack(context, 'Could not save the template.', error: true);
      }
    }
  }

  Future<void> _choose({bool reuse = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = reuse ? _files : await pickCsvFiles();
      if (files.isEmpty) return;
      final rows = <ImportRow>[], errors = <String>[];
      for (final f in files) {
        if (f.error != null) {
          errors.add(f.error!);
          continue;
        }
        final p = validateImport(f.text, f.name, defaultType: _defaultType);
        rows.addAll(p.rows);
        errors.addAll(p.errors);
      }
      if (rows.length > 2000) {
        errors.add('Select at most 2,000 rows in one import.');
        rows.clear();
      }
      var added = 0, skipped = 0;
      if (rows.isNotEmpty) {
        for (final key in rows.map((r) => r.storageKey).toSet()) {
          final selected = rows.where((r) => r.storageKey == key);
          final kind = selected.first.kind;
          final raw = key == 'pw_lectures_tree'
              ? await ref.read(adminRepositoryProvider).read(key)
              : null;
          final tree = key == 'pw_lectures_tree'
              ? (raw is List ? raw : [])
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList()
              : await ref.read(adminRepositoryProvider).tree(kind);
          var sequence = 0;
          final result = key == 'pw_lectures_tree'
              ? mergeLectureRows(tree, selected, () => 'preview-${sequence++}')
              : mergeRows(tree, selected, () => 'preview-${sequence++}');
          added += result.added;
          skipped += result.skipped;
          errors.addAll(result.conflicts);
        }
      }
      if (mounted) {
        setState(() {
          _files = files;
          _preview = ImportPreview(rows, errors);
          _added = added;
          _skipped = skipped;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.message ?? 'Could not read CSV, JSON or XLSX files.',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        setState(
          () => _error =
              'File selection is available in the Android app and web version.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not prepare import. Check the file encoding, connection and admin access.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (_busy || preview == null || !preview.valid || _added == 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(adminRepositoryProvider)
          .importRows(preview.rows, _files.map((f) => f.name).toList());
      for (final kind in preview.rows.map((r) => r.kind).toSet()) {
        ref.invalidate(adminTreeProvider(kind));
      }
      await refreshContent(ref, preview.rows.map((r) => r.storageKey).toSet());
      if (mounted) {
        setState(() {
          _preview = null;
          _files = [];
        });
        showHSnack(
          context,
          '${result.added} files imported · ${result.skipped} duplicates skipped',
        );
      }
    } on FriendlyException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Import could not be saved. Your preview is still here; check connection and admin access before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isAdminProvider)) {
      return const Scaffold(
        body: EmptyState(icon: Icons.lock_rounded, title: 'Admins only'),
      );
    }
    final preview = _preview;
    return TabPage(
      title: 'Bulk import',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: HSpace.screen),
          sliver: SliverList.list(
            children: [
              // Template stays at the top, above file selection.
              HButton(
                label: 'CSV template',
                icon: Icons.file_download_outlined,
                onPressed: _busy ? null : _template,
                outlined: true,
              ),
              const Gap(HSpace.sm),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _template('json'),
                    icon: const Icon(Icons.data_object_rounded, size: 18),
                    label: const Text('JSON template'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _template('xlsx'),
                    icon: const Icon(Icons.table_view_rounded, size: 18),
                    label: const Text('Excel template'),
                  ),
                ],
              ),
              const Gap(HSpace.md),
              const HeroPanel(
                eyebrow: 'Admin',
                title: 'Add many files at once',
                subtitle:
                    'Choose multiple CSV, JSON or XLSX files, review the preview, then import.',
                icon: Icons.upload_file_rounded,
              ),
              const Gap(HSpace.md),
              const Text(
                'Use the website’s CSV, JSON or Excel templates. Sheets and resource types are detected automatically. Review valid rows, skipped duplicates and errors before importing.',
              ),
              const Gap(HSpace.md),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _defaultType,
                decoration: const InputDecoration(labelText: 'Resource type'),
                items: [
                  for (final kind in [
                    'auto',
                    'notes',
                    'special',
                    'mcqs',
                    'papers',
                    'lectures',
                  ])
                    DropdownMenuItem(
                      value: kind,
                      child: Text(kind == 'auto' ? 'Auto-detect' : kind),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() {
                          _defaultType = value ?? 'auto';
                          _preview = null;
                        });
                        if (_files.isNotEmpty) _choose(reuse: true);
                      },
              ),
              const Gap(HSpace.md),
              HButton(
                label: 'Choose import files',
                icon: Icons.folder_open_rounded,
                loading: _busy,
                onPressed: _busy ? null : _choose,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: HSpace.md),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: HColors.error),
                  ),
                ),
              if (preview != null) ...[
                const Gap(HSpace.lg),
                SectionHeader(
                  title: '${_files.length} CSV, JSON or XLSX files selected',
                ),
                for (final file in _files)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(file.name),
                  ),
                const Gap(HSpace.md),
                if (preview.errors.isNotEmpty) ...[
                  Text(
                    '${preview.errors.length} invalid rows will be skipped',
                    style: const TextStyle(
                      color: HColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (final error in preview.errors.take(30))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(error),
                    ),
                  if (preview.errors.length > 30)
                    const Text(
                      'More errors exist. Correct these and select the files again.',
                    ),
                ],
                if (preview.rows.isNotEmpty) ...[
                  HeroPanel(
                    eyebrow: 'Import preview',
                    title: '$_added new files',
                    subtitle:
                        '$_skipped duplicate links will be skipped. Conflicting lecture links are excluded.',
                    icon: Icons.fact_check_outlined,
                  ),
                  const Gap(HSpace.md),
                  for (final row in preview.rows.take(8))
                    ResourceTile(
                      icon: Icons.picture_as_pdf_outlined,
                      color: HColors.primary,
                      title: row.title,
                      subtitle:
                          '${row.lecture ? 'Lectures' : row.kind.title} · ${row.labels.join(' › ')}',
                      trailing: const SizedBox.shrink(),
                    ),
                  if (preview.rows.length > 8)
                    Text('And ${preview.rows.length - 8} more rows.'),
                  const Gap(HSpace.md),
                  HButton(
                    label: _added == 0
                        ? 'All files already exist'
                        : 'Import $_added new files',
                    icon: Icons.cloud_upload_outlined,
                    onPressed: _busy || _added == 0 ? null : _import,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

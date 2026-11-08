import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/media_upload.dart';
import '../../../core/widgets/common.dart';
import '../data/pdf_studio_repository.dart';
import '../data/studio_file_item.dart';
import '../data/studio_pdf_engine.dart';
import 'office_ui.dart';
import 'rich_document_screen.dart';
import 'studio_annotation_screen.dart';
import 'studio_export_sheet.dart';
import 'studio_tools_screen.dart';

String studioMime(String path) => switch (path.split('.').last.toLowerCase()) {
  'pdf' => 'application/pdf',
  'doc' => 'application/msword',
  'docx' =>
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'ppt' => 'application/vnd.ms-powerpoint',
  'pptx' =>
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'xls' => 'application/vnd.ms-excel',
  'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'txt' => 'text/plain',
  'md' => 'text/markdown',
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  'zip' => 'application/zip',
  _ => 'application/octet-stream',
};

bool isStudioPdf(StudioFileItem f) =>
    f.internalFilePath.toLowerCase().endsWith('.pdf');

String _baseName(StudioFileItem f) =>
    f.displayName.replaceFirst(RegExp(r'\.[^.]+$'), '');

void openStudioTool(
  BuildContext context,
  StudioTool tool, [
  StudioFileItem? file,
]) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => StudioToolsScreen(tool: tool, initialFile: file),
  ),
);

void openStudioReader(BuildContext context, StudioFileItem file) =>
    context.push('/pdf-studio/viewer/${file.id}');

/// Runs [task] behind a small non-dismissible progress dialog.
Future<T?> _withProgress<T>(
  BuildContext context,
  String label,
  Future<T> Function() task,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (c) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 18),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    if (navigator.mounted) navigator.pop();
  }
}

Future<void> shareStudioFile(BuildContext context, StudioFileItem file) async {
  try {
    await MediaUpload.shareDocument(
      file.internalFilePath,
      file.displayName,
      studioMime(file.internalFilePath),
    );
  } catch (_) {
    if (context.mounted) {
      showHSnack(context, 'Could not share this file.', error: true);
    }
  }
}

Future<void> copyStudioFileToDevice(
  BuildContext context,
  StudioFileItem file,
) async {
  try {
    final ok = await MediaUpload.exportDocument(
      file.internalFilePath,
      file.displayName,
      studioMime(file.internalFilePath),
    );
    if (ok && context.mounted) showHSnack(context, 'Saved to your device');
  } catch (_) {
    if (context.mounted) {
      showHSnack(context, 'Could not save a copy.', error: true);
    }
  }
}

/// Every page as a JPEG, packed into one ZIP the user saves anywhere.
Future<void> saveStudioFileAsJpeg(
  BuildContext context,
  StudioFileItem file,
) async {
  if (!isStudioPdf(file)) return copyStudioFileToDevice(context, file);
  try {
    final zip = await _withProgress(
      context,
      'Preparing JPEG pages…',
      () => StudioPdfEngine.pagesToImages(file.internalFilePath, 'jpg'),
    );
    if (zip == null || zip.isEmpty || !context.mounted) return;
    final ok = await MediaUpload.exportDocument(
      zip,
      '${_baseName(file)}_pages.zip',
      'application/zip',
    );
    if (ok && context.mounted) showHSnack(context, 'JPEG pages saved');
  } catch (_) {
    if (context.mounted) {
      showHSnack(context, 'Could not create JPEG pages.', error: true);
    }
  }
}

/// PDFs get the annotation/text editor; text documents the writer.
void editStudioText(BuildContext context, StudioFileItem file) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (isStudioPdf(file)) {
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => StudioAnnotationScreen(file: file),
      ),
    );
  } else {
    openStudioTool(context, StudioTool.document, file);
  }
}

Future<void> renameStudioFile(
  BuildContext context,
  WidgetRef ref,
  StudioFileItem file,
) async {
  final name = await askOfficeText(
    context,
    title: 'Rename document',
    initial: file.displayName,
    label: 'Display name',
  );
  if (name != null && name.trim().isNotEmpty) {
    await ref.read(pdfStudioHistoryProvider.notifier).rename(file.id, name);
  }
}

Future<String?> askOfficeText(
  BuildContext context, {
  required String title,
  required String initial,
  required String label,
}) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(labelText: label, counterText: ''),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

Future<void> deleteStudioFile(
  BuildContext context,
  WidgetRef ref,
  StudioFileItem file,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (c) => AlertDialog(
      title: const Text('Delete workspace copy?'),
      content: Text('“${file.displayName}” will be deleted from Studio.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirm == true) {
    OfficeImageCache.forget(file.internalFilePath);
    await ref.read(pdfStudioHistoryProvider.notifier).delete(file.id);
  }
}

Future<String?> _askPassword(BuildContext context) async {
  final password = TextEditingController();
  final confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (c) => AlertDialog(
      title: const Text('Set password'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => (v?.length ?? 0) < 6
                  ? 'Use at least 6 characters'
                  : (v?.length ?? 0) > 128
                  ? 'Use up to 128 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirm,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (v) =>
                  v != password.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'A protected copy is saved. The password cannot be recovered.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(c, password.text);
          },
          child: const Text('Protect'),
        ),
      ],
    ),
  );
  password.dispose();
  confirm.dispose();
  return result;
}

/// Creates a processed copy (protected / compressed) and opens it.
Future<void> _processedCopy(
  BuildContext context,
  WidgetRef ref,
  StudioFileItem file, {
  required String label,
  required String suffix,
  required String badge,
  required Future<String> Function() run,
}) async {
  final router = GoRouter.of(context);
  final notifier = ref.read(pdfStudioHistoryProvider.notifier);
  try {
    final item = await _withProgress(context, label, () async {
      final path = await run();
      if (path.isEmpty) throw const FormatException('No output');
      final copy = await notifier.importFile(
        path,
        originalFileName: '${_baseName(file)} ($suffix).pdf',
        sourceType: 'CREATED',
        operationBadge: badge,
      );
      final pages = await StudioPdfEngine.pageCount(copy.internalFilePath);
      if (pages > 0) await notifier.updatePageCount(copy.id, pages);
      return copy;
    });
    if (item != null && context.mounted) {
      showHSnack(context, 'Saved “${item.displayName}”');
      router.push('/pdf-studio/viewer/${item.id}');
    }
  } catch (_) {
    if (context.mounted) {
      showHSnack(context, 'Could not finish. Please retry.', error: true);
    }
  }
}

Future<void> protectStudioFile(
  BuildContext context,
  WidgetRef ref,
  StudioFileItem file,
) async {
  final password = await _askPassword(context);
  if (password == null || !context.mounted) return;
  await _processedCopy(
    context,
    ref,
    file,
    label: 'Protecting PDF…',
    suffix: 'protected',
    badge: 'PROTECTED',
    run: () => StudioPdfEngine.protect(file.internalFilePath, password),
  );
}

Future<void> compressStudioFile(
  BuildContext context,
  WidgetRef ref,
  StudioFileItem file,
) => _processedCopy(
  context,
  ref,
  file,
  label: 'Compressing PDF…',
  suffix: 'compressed',
  badge: 'COMPRESSED',
  run: () => StudioPdfEngine.compress(file.internalFilePath, 'balanced'),
);

/// The "More" sheet from the approved design.
Future<void> showOfficeFileMore(
  BuildContext context,
  WidgetRef ref,
  StudioFileItem file,
) async {
  final pdf = isStudioPdf(file);
  final action = await showOfficeSheet<String>(
    context,
    (sheet) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      children: [
        OfficeSheetItem(
          icon: Icons.cloud_download_outlined,
          label: 'Copy to device',
          onTap: () => Navigator.pop(sheet, 'device'),
        ),
        OfficeSheetItem(
          icon: Icons.cloud_upload_rounded,
          label: 'Share',
          onTap: () => Navigator.pop(sheet, 'share'),
        ),
        const OfficeSheetDivider(),
        if (pdf) ...[
          OfficeSheetItem(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Export PDF',
            onTap: () => Navigator.pop(sheet, 'export'),
          ),
          OfficeSheetItem(
            icon: Icons.library_add_outlined,
            label: 'Combine files',
            onTap: () => Navigator.pop(sheet, 'merge'),
          ),
          OfficeSheetItem(
            icon: Icons.output_rounded,
            label: 'Extract pages',
            onTap: () => Navigator.pop(sheet, 'extract'),
          ),
          OfficeSheetItem(
            icon: Icons.lock_outline_rounded,
            label: 'Set password',
            onTap: () => Navigator.pop(sheet, 'password'),
          ),
          OfficeSheetItem(
            icon: Icons.compress_rounded,
            label: 'Compress PDF',
            onTap: () => Navigator.pop(sheet, 'compress'),
          ),
          const OfficeSheetDivider(),
        ] else
          OfficeSheetItem(
            icon: Icons.ios_share_rounded,
            label: 'Export file',
            onTap: () => Navigator.pop(sheet, 'export'),
          ),
        OfficeSheetItem(
          icon: Icons.chrome_reader_mode_outlined,
          label: 'Open in reader',
          onTap: () => Navigator.pop(sheet, 'open'),
        ),
        if (pdf) ...[
          OfficeSheetItem(
            icon: Icons.draw_outlined,
            label: 'Fill & Sign',
            onTap: () => Navigator.pop(sheet, 'sign'),
          ),
          OfficeSheetItem(
            icon: Icons.edit_document,
            label: 'Modify scan',
            onTap: () => Navigator.pop(sheet, 'organize'),
          ),
        ],
        OfficeSheetItem(
          icon: Icons.edit_rounded,
          label: 'Rename',
          onTap: () => Navigator.pop(sheet, 'rename'),
        ),
        OfficeSheetItem(
          icon: file.isStarred
              ? Icons.star_rounded
              : Icons.drive_file_move_outline,
          label: file.isStarred ? 'Remove from Starred' : 'Move to Starred',
          onTap: () => Navigator.pop(sheet, 'star'),
        ),
        OfficeSheetItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          destructive: true,
          onTap: () => Navigator.pop(sheet, 'delete'),
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'device':
      await copyStudioFileToDevice(context, file);
    case 'share':
      await shareStudioFile(context, file);
    case 'export':
      await showStudioExportSheet(context, file);
    case 'merge':
      openStudioTool(context, StudioTool.merge, file);
    case 'extract':
      openStudioTool(context, StudioTool.extract, file);
    case 'password':
      await protectStudioFile(context, ref, file);
    case 'compress':
      await compressStudioFile(context, ref, file);
    case 'open':
      openStudioReader(context, file);
    case 'sign':
      editStudioText(context, file);
    case 'organize':
      openStudioTool(context, StudioTool.organize, file);
    case 'rename':
      await renameStudioFile(context, ref, file);
    case 'star':
      await ref
          .read(pdfStudioHistoryProvider.notifier)
          .setStarred(file.id, !file.isStarred);
    case 'delete':
      await deleteStudioFile(context, ref, file);
  }
}

/// Create & tools sheet behind the workspace "smart tools" button.
Future<void> showOfficeToolsSheet(BuildContext context) async {
  final router = GoRouter.of(context);
  final action = await showOfficeSheet<String>(
    context,
    (sheet) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      children: [
        OfficeSheetItem(
          icon: Icons.document_scanner_outlined,
          label: 'Scan document',
          onTap: () => Navigator.pop(sheet, 'scan'),
        ),
        OfficeSheetItem(
          icon: Icons.photo_library_outlined,
          label: 'Images to PDF',
          onTap: () => Navigator.pop(sheet, 'gallery'),
        ),
        OfficeSheetItem(
          icon: Icons.folder_open_outlined,
          label: 'Open a file',
          onTap: () => Navigator.pop(sheet, 'open'),
        ),
        OfficeSheetItem(
          icon: Icons.edit_note_rounded,
          label: 'Write a document',
          onTap: () => Navigator.pop(sheet, 'write'),
        ),
        const OfficeSheetDivider(),
        OfficeSheetItem(
          icon: Icons.library_add_outlined,
          label: 'Combine files',
          onTap: () => Navigator.pop(sheet, 'merge'),
        ),
        OfficeSheetItem(
          icon: Icons.output_rounded,
          label: 'Extract pages',
          onTap: () => Navigator.pop(sheet, 'extract'),
        ),
        OfficeSheetItem(
          icon: Icons.call_split_rounded,
          label: 'Split by range',
          onTap: () => Navigator.pop(sheet, 'split'),
        ),
        OfficeSheetItem(
          icon: Icons.view_module_outlined,
          label: 'Organize pages',
          onTap: () => Navigator.pop(sheet, 'organize'),
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'scan':
      router.push('/create-pdf?source=camera');
    case 'gallery':
      router.push('/create-pdf?source=gallery');
    case 'open':
      openStudioTool(context, StudioTool.open);
    case 'write':
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => const RichDocumentScreen()),
      );
    case 'merge':
      openStudioTool(context, StudioTool.merge);
    case 'extract':
      openStudioTool(context, StudioTool.extract);
    case 'split':
      openStudioTool(context, StudioTool.split);
    case 'organize':
      openStudioTool(context, StudioTool.organize);
  }
}

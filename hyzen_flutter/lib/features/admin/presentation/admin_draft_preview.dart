import 'package:flutter/material.dart';

import '../../../core/widgets/ui_kit.dart';

Map<String, dynamic> mergeAdminDraft(
  Map<String, dynamic> initial,
  Map<String, dynamic> updates,
) {
  final result = <String, dynamic>{
    for (final entry in initial.entries)
      entry.key: entry.value is Map
          ? Map<String, dynamic>.from(
              (entry.value as Map).cast<String, dynamic>(),
            )
          : entry.value,
  };
  for (final entry in updates.entries) {
    final parts = entry.key.split('.');
    Map<String, dynamic> target = result;
    for (final part in parts.take(parts.length - 1)) {
      final child = target[part];
      if (child is Map) {
        final next = Map<String, dynamic>.from(child.cast<String, dynamic>());
        target[part] = next;
        target = next;
      } else {
        final next = <String, dynamic>{};
        target[part] = next;
        target = next;
      }
    }
    target[parts.last] = entry.value;
  }
  return result;
}

Object? _draftValue(Map<String, dynamic> draft, String path) {
  Object? value = draft;
  for (final part in path.split('.')) {
    if (value is! Map) return null;
    value = value[part];
  }
  return value;
}

Color _draftColor(Object? raw, Color fallback) {
  final value = (raw ?? '').toString().trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return fallback;
  return Color(int.parse('FF$value', radix: 16));
}

Future<void> showAdminDraftPreview(
  BuildContext context,
  String section,
  Map<String, dynamic> draft,
) async {
  final notice = section == 'notice';
  final title = (_draftValue(draft, notice ? 'title' : 'text') ?? '')
      .toString()
      .trim();
  final body = (_draftValue(draft, 'body') ?? '').toString().trim();
  final eyebrow = (_draftValue(draft, 'eyebrow') ?? '').toString().trim();
  final background = _draftColor(
    _draftValue(draft, notice ? 'background' : 'gradient.from'),
    notice ? const Color(0xFFF4F4F5) : const Color(0xFF222226),
  );
  final card = _draftColor(
    _draftValue(draft, notice ? 'card' : 'gradient.to'),
    notice ? Colors.white : const Color(0xFF111113),
  );
  final foreground = _draftColor(
    _draftValue(draft, notice ? 'text' : 'textColor'),
    notice ? const Color(0xFF171719) : Colors.white,
  );
  final accent = _draftColor(
    _draftValue(draft, notice ? 'accent' : 'textColor'),
    foreground,
  );
  final image = (_draftValue(draft, 'image') ?? '').toString().trim();
  final primary = (_draftValue(draft, notice ? 'primaryText' : 'linkText') ?? '')
      .toString()
      .trim();
  final secondary = (_draftValue(draft, 'secondaryText') ?? '')
      .toString()
      .trim();
  final dismiss = (_draftValue(draft, 'dismissText') ?? 'Maybe later')
      .toString();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        decoration: BoxDecoration(
          color: notice ? background : null,
          gradient: notice
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [background, card],
                ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'STUDENT VIEW · PREVIEW ONLY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: notice ? card : Colors.white.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: foreground.withValues(alpha: .16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (eyebrow.isNotEmpty)
                        Text(
                          eyebrow,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      if (image.startsWith('https://')) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: NetImage(image, height: 150),
                        ),
                      ],
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: TextStyle(
                            color: foreground,
                            fontSize: notice ? 22 : 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ] else if (!notice)
                        Text(
                          'Your announcement will appear here.',
                          style: TextStyle(color: foreground),
                        ),
                      if (notice && body.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          body,
                          style: TextStyle(color: foreground, height: 1.5),
                        ),
                      ],
                      if (primary.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: null,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: notice ? card : background,
                            ),
                            child: Text(primary),
                          ),
                        ),
                      ],
                      if (secondary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(secondary, style: TextStyle(color: foreground)),
                      ],
                      if (notice) ...[
                        const SizedBox(height: 8),
                        Text(
                          dismiss,
                          style: TextStyle(
                            color: foreground.withValues(alpha: .72),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
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
Future<void> showAdminBlogPreview(
  BuildContext context,
  Map<String, dynamic> draft,
) async {
  final title = (draft['title'] ?? 'Untitled article').toString().trim();
  final author = (draft['author'] ?? 'Hyzen').toString().trim();
  final excerpt = (draft['excerpt'] ?? '').toString().trim();
  final html = (draft['contentHtml'] ?? '').toString();
  final image = (draft['coverImage'] ?? '').toString().trim();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'STUDENT ARTICLE PREVIEW · NOT PUBLISHED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .9,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close preview',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image.startsWith('https://'))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: NetImage(image, height: 190),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      title.isEmpty ? 'Untitled article' : title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      author.isEmpty ? 'Hyzen' : author,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (excerpt.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        excerpt,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (html.trim().isEmpty)
                      const Text('Article content will appear here.')
                    else
                      HtmlText(html),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

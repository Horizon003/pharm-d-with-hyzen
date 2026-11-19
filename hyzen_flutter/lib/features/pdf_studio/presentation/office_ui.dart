import 'dart:typed_data';
import '../../../core/widgets/workspace_icons.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/config/brand.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../notifications/notifications_screen.dart';
import '../../shell/app_shell.dart' show showAccountMenu;
import '../../viewer/document_bytes.dart';
import '../data/studio_pdf_engine.dart';

/// Neutral document surfaces matching the home and study hierarchy.
class OfficeColors {
  OfficeColors._();
  static const blue = Color(0xFF737373);
  static const navy = Color(0xFF333333);
  static bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color canvas(BuildContext c) =>
      Theme.of(c).colorScheme.surfaceContainer;
  static Color page(BuildContext c) => HColors.background;
  static Color bar(BuildContext c) => Theme.of(c).scaffoldBackgroundColor;
  static Color sheet(BuildContext c) => Theme.of(c).colorScheme.surface;
  static Color raised(BuildContext c) =>
      Theme.of(c).colorScheme.surfaceContainer;
  static Color ink(BuildContext c) => Theme.of(c).colorScheme.onSurface;
  static Color muted(BuildContext c) =>
      Theme.of(c).colorScheme.onSurfaceVariant;
  static Color divider(BuildContext c) =>
      Theme.of(c).colorScheme.outlineVariant;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String officeDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String officeRelativeDate(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return officeDate(d);
}

/// Brand row: panda mark, wordmark, notification bell and profile avatar.
class OfficeBrandHeader extends ConsumerWidget {
  const OfficeBrandHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(firebaseReadyProvider);
    return ColoredBox(
      color: OfficeColors.bar(context),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    Brand.logoAsset,
                    width: 36,
                    height: 36,
                    cacheWidth: 108,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PHARM D WITH HYZEN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: OfficeColors.ink(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 16.5,
                      letterSpacing: -.1,
                    ),
                  ),
                ),
                // Account widgets need Firebase; previews/tests run without it.
                if (ready) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: OfficeColors.raised(context),
                      shape: BoxShape.circle,
                    ),
                    child: const NotificationBell(),
                  ),
                  const SizedBox(width: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final p = ref.watch(profileProvider).valueOrNull;
                      return Semantics(
                        button: true,
                        label: 'Profile & settings',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showAccountMenu(context),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: OfficeColors.divider(context),
                                width: 1.5,
                              ),
                            ),
                            child: ProfileAvatar(
                              photoUrl: ProfileAvatar.resolveUrl(
                                p?.photoUrl,
                                ref
                                    .watch(authStateProvider)
                                    .valueOrNull
                                    ?.photoURL,
                              ),
                              radius: 19,
                              fallback: p?.firstName ?? 'H',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle officePrimaryStyle() => FilledButton.styleFrom(
  backgroundColor: OfficeColors.blue,
  foregroundColor: Colors.white,
  disabledBackgroundColor: OfficeColors.blue.withValues(alpha: .35),
  disabledForegroundColor: Colors.white70,
  minimumSize: const Size(0, 36),
  shape: const StadiumBorder(),
  textStyle: const TextStyle(
    fontFamily: 'Outfit',
    fontSize: 12,
    fontWeight: FontWeight.w600,
  ),
);

ButtonStyle officeOutlineStyle(BuildContext context) =>
    OutlinedButton.styleFrom(
      foregroundColor: OfficeColors.ink(context),
      minimumSize: const Size(0, 36),
      shape: const StadiumBorder(),
      side: BorderSide(
        color: OfficeColors.ink(context).withValues(alpha: .55),
        width: 1.4,
      ),
      textStyle: const TextStyle(
        fontFamily: 'Outfit',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );

/// Encoded image bytes plus aspect ratio, read without a full decode.
class PageImageData {
  const PageImageData(this.bytes, this.ratio);
  final Uint8List bytes;
  final double ratio;
}

/// Small LRU caches so scrolling lists and page switches never re-read or
/// re-render the same file (main source of jank on mid-range phones).
class OfficeImageCache {
  OfficeImageCache._();
  // Map literals are insertion-ordered (LinkedHashMap), which the LRU needs.
  static final _pages = <String, Future<PageImageData?>>{};
  static final _pdf = <String, Future<Uint8List?>>{};

  static Future<T> _lru<T>(
    Map<String, Future<T>> map,
    String key,
    int max,
    Future<T> Function() load,
  ) {
    final hit = map.remove(key);
    if (hit != null) return map[key] = hit;
    final future = load();
    map[key] = future;
    while (map.length > max) {
      map.remove(map.keys.first);
    }
    return future;
  }

  static Future<PageImageData?> image(String path) =>
      _lru(_pages, path, 16, () async {
        try {
          final bytes = await documentBytes(path);
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final descriptor = await ui.ImageDescriptor.encoded(buffer);
          final ratio = descriptor.height == 0
              ? .75
              : descriptor.width / descriptor.height;
          descriptor.dispose();
          buffer.dispose();
          return PageImageData(bytes, ratio);
        } catch (_) {
          return null;
        }
      });

  static Future<Uint8List?> pdfFirstPage(String path, String version) =>
      _lru(_pdf, '$path#$version', 24, () async {
        try {
          return (await StudioPdfEngine.renderPage(path, 0)).bytes;
        } catch (_) {
          return null;
        }
      });

  static void forget(String path) {
    _pages.remove(path);
    _pdf.removeWhere((k, _) => k.startsWith('$path#'));
  }
}

/// Paper-style first-page preview of a workspace document.
class OfficeFileThumbnail extends StatefulWidget {
  const OfficeFileThumbnail({
    super.key,
    required this.path,
    required this.version,
    this.fallbackIcon = Icons.description_outlined,
    this.alignment = Alignment.topCenter,
  });
  final String path, version;
  final IconData fallbackIcon;
  final Alignment alignment;

  @override
  State<OfficeFileThumbnail> createState() => _OfficeFileThumbnailState();
}

class _OfficeFileThumbnailState extends State<OfficeFileThumbnail> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() {
    final lower = widget.path.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return OfficeImageCache.pdfFirstPage(widget.path, widget.version);
    }
    if (RegExp(r'\.(jpe?g|png|webp)$').hasMatch(lower)) {
      return OfficeImageCache.image(widget.path).then((d) => d?.bytes);
    }
    return Future.value(null);
  }

  @override
  void didUpdateWidget(covariant OfficeFileThumbnail old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.version != widget.version) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LayoutBuilder(
          builder: (context, box) => FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (context, snap) {
              final data = snap.data;
              if (data == null) {
                return Center(
                  child: WorkspaceIcon(
                    widget.path.toLowerCase().endsWith('.pdf')
                        ? WorkspaceGlyph.pdf
                        : widget.path.toLowerCase().contains('.ppt')
                        ? WorkspaceGlyph.slides
                        : WorkspaceGlyph.word,
                    size: (box.maxWidth * .65).clamp(24.0, 64.0),
                  ),
                );
              }
              return Image.memory(
                data,
                fit: BoxFit.cover,
                alignment: widget.alignment,
                gaplessPlayback: true,
                cacheWidth:
                    (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
                        .round()
                        .clamp(48, 720),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Rounded bottom sheet chrome shared by the Office sheets.
Future<T?> showOfficeSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OfficeColors.sheet(context),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: OfficeColors.muted(sheet).withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(child: builder(sheet)),
            ],
          ),
        ),
      ),
    );

/// One row of an Office action sheet.
class OfficeSheetItem extends StatelessWidget {
  const OfficeSheetItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFE5484D)
        : OfficeColors.ink(context);
    final glyph = controlGlyphForIcon(icon);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        child: Row(
          children: [
            if (glyph == null)
              Icon(icon, size: 23, color: color)
            else
              ControlIcon(glyph, size: 23),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfficeSheetDivider extends StatelessWidget {
  const OfficeSheetDivider({super.key});
  @override
  Widget build(BuildContext context) => Divider(
    height: 14,
    thickness: 1,
    indent: 38,
    endIndent: 32,
    color: OfficeColors.divider(context),
  );
}

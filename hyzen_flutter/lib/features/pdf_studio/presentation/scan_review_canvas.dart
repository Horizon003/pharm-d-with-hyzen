import 'package:flutter/material.dart';

import 'office_ui.dart';

/// Original-photo preview with four independent perspective-crop corners.
class ScanReviewCanvas extends StatelessWidget {
  const ScanReviewCanvas({
    super.key,
    required this.path,
    required this.crop,
    required this.quad,
    required this.onQuad,
  });
  final String path;
  final bool crop;
  final List<Offset> quad;
  final ValueChanged<List<Offset>> onQuad;

  void _drag(int index, Offset delta, Size size) {
    final next = [...quad];
    next[index] = Offset(
      (quad[index].dx + delta.dx / size.width).clamp(0, 1),
      (quad[index].dy + delta.dy / size.height).clamp(0, 1),
    );
    if (validCropQuad(next)) onQuad(next);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PageImageData?>(
    future: OfficeImageCache.image(path),
    builder: (context, snap) {
      final data = snap.data;
      if (data == null) {
        return Center(
          child: snap.connectionState == ConnectionState.done
              ? Icon(
                  Icons.broken_image_outlined,
                  color: OfficeColors.muted(context),
                  size: 48,
                )
              // Static placeholder: no endless spinner while bytes load.
              : Icon(
                  Icons.image_outlined,
                  color: OfficeColors.muted(context),
                  size: 48,
                ),
        );
      }
      return LayoutBuilder(
        builder: (context, box) {
          // Reserve the full 44px hit area even at the photo's boundaries.
          final margin = crop ? 22.0 : 0.0;
          final available = Size(
            (box.maxWidth - margin * 2).clamp(1.0, double.infinity),
            (box.maxHeight - margin * 2).clamp(1.0, double.infinity),
          );
          final size = applyBoxFit(
            BoxFit.contain,
            Size(data.ratio, 1),
            available,
          ).destination;
          final photoRect = Offset(margin, margin) & size;
          Offset at(double x, double y) =>
              Offset(margin + x * size.width, margin + y * size.height);
          final points = [for (final p in quad) at(p.dx, p.dy)];
          return Center(
            child: SizedBox(
              width: size.width + margin * 2,
              height: size.height + margin * 2,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fromRect(
                    rect: photoRect,
                    child: RepaintBoundary(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.memory(
                          data.bytes,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          cacheWidth:
                              (size.width *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round()
                                  .clamp(200, 1600),
                        ),
                      ),
                    ),
                  ),
                  if (crop) ...[
                    Positioned.fromRect(
                      rect: photoRect,
                      child: IgnorePointer(
                        child: CustomPaint(painter: _CropFrame(quad)),
                      ),
                    ),
                    for (var i = 0; i < 4; i++)
                      Positioned(
                        left: points[i].dx - 22,
                        top: points[i].dy - 22,
                        child: Semantics(
                          label: 'Corner crop handle ${i + 1}',
                          child: GestureDetector(
                            key: ValueKey('crop-handle-$i'),
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (d) => _drag(i, d.delta, size),
                            child: SizedBox.square(
                              dimension: 44,
                              child: Center(
                                child: _Handle(corner: true, vertical: false),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _Handle extends StatelessWidget {
  const _Handle({required this.corner, required this.vertical});
  final bool corner, vertical;
  @override
  Widget build(BuildContext context) => Container(
    width: corner ? 22 : (vertical ? 13 : 30),
    height: corner ? 22 : (vertical ? 30 : 13),
    decoration: BoxDecoration(
      color: Colors.white,
      shape: corner ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: corner ? null : BorderRadius.circular(3),
      border: Border.all(color: OfficeColors.blue, width: 2.4),
    ),
  );
}

class _CropFrame extends CustomPainter {
  _CropFrame(this.quad);
  final List<Offset> quad;
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..moveTo(quad[0].dx * size.width, quad[0].dy * size.height);
    for (final point in quad.skip(1)) {
      outline.lineTo(point.dx * size.width, point.dy * size.height);
    }
    outline.close();
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addPath(outline, Offset.zero),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..color = OfficeColors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  @override
  bool shouldRepaint(covariant _CropFrame old) => old.quad != quad;
}

/// Numbered thumbnail strip (long-press and drag to reorder).
class ScanThumbStrip extends StatelessWidget {
  const ScanThumbStrip({
    super.key,
    required this.pages,
    required this.selected,
    required this.onSelect,
    required this.onReorder,
    required this.onOptions,
    this.onAdd,
  });
  final List<String> pages;
  final int selected;
  final ValueChanged<int> onSelect, onOptions;
  final VoidCallback? onAdd;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 84,
    child: ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      footer: SizedBox(
        width: 64,
        child: IconButton(
          key: const ValueKey('scan-more'),
          tooltip: 'Scan and append page',
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ),
      itemCount: pages.length,
      onReorder: (from, to) => onReorder(from, to > from ? to - 1 : to),
      proxyDecorator: (child, _, __) =>
          Material(color: Colors.transparent, child: child),
      itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(pages[i]),
        index: i,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Semantics(
            button: true,
            selected: i == selected,
            label: 'Page ${i + 1}',
            child: GestureDetector(
              onTap: () => onSelect(i),
              onDoubleTap: () => onOptions(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 62,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: OfficeColors.dark(context)
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE6E8EC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: i == selected
                        ? OfficeColors.blue
                        : Colors.transparent,
                    width: 2.4,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: OfficeFileThumbnail(
                          path: pages[i],
                          version: pages[i],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC5A5A5E),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Small rounded pill like "Straighten" / "Page 1 of 4".
class ScanPill extends StatelessWidget {
  const ScanPill({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.onTap,
  });
  final String label;
  final IconData? icon, trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ink = OfficeColors.ink(context);
    return Material(
      color: OfficeColors.dark(context)
          ? const Color(0xFF2C2C2E)
          : const Color(0xFFE6E8EC),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: OfficeColors.blue, size: 24),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Icon(trailing, color: ink, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ScanRoundButton extends StatelessWidget {
  const ScanRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: OfficeColors.dark(context) ? const Color(0xFF2C2C2E) : Colors.white,
    shape: const CircleBorder(),
    elevation: 1,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        color: onTap == null
            ? OfficeColors.muted(context)
            : OfficeColors.ink(context),
      ),
    ),
  );
}

/// Reject crossed or collapsed corners without constraining a corner to a rectangle.
bool validCropQuad(List<Offset> points) {
  if (points.length != 4 ||
      points.any(
        (p) =>
            !p.dx.isFinite ||
            !p.dy.isFinite ||
            p.dx < 0 ||
            p.dx > 1 ||
            p.dy < 0 ||
            p.dy > 1,
      )) {
    return false;
  }
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final a = points[i], b = points[(i + 1) % 4], c = points[(i + 2) % 4];
    final cross = (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
    if (cross <= .00001) return false;
    area += a.dx * b.dy - b.dx * a.dy;
  }
  return area / 2 > .01;
}

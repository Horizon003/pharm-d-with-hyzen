import 'package:flutter/material.dart';

import '../../../core/widgets/workspace_icons.dart';

/// Lazy page thumbnails with long-press drag targets; large images are never
/// decoded by the grid itself. The owning draft persists every move.
class PageGrid extends StatelessWidget {
  const PageGrid({
    super.key,
    required this.count,
    required this.image,
    required this.identity,
    required this.onMove,
    this.selected = const {},
    this.onSelect,
    this.onEdit,
    this.onRotate,
    this.onRemove,
  });
  final int count;
  final Widget Function(int) image;
  final Object Function(int) identity;
  final void Function(int, int) onMove;
  final Set<int> selected;
  final void Function(int)? onSelect, onEdit, onRotate, onRemove;
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 210,
      mainAxisExtent: MediaQuery.textScalerOf(context).scale(1) > 1.4
          ? 254
          : 224,
      mainAxisSpacing: 18,
      crossAxisSpacing: 20,
    ),
    itemCount: count,
    itemBuilder: (c, i) {
      final scheme = Theme.of(c).colorScheme;
      final card = Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected.contains(i)
                ? scheme.primary
                : scheme.outlineVariant,
            width: selected.contains(i) ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect != null ? onSelect!(i) : onEdit?.call(i),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: image(i),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      'Page ${i + 1}',
                      style: Theme.of(c).textTheme.labelSmall,
                    ),
                    const Spacer(),
                    if (onSelect != null)
                      Icon(
                        selected.contains(i)
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected.contains(i)
                            ? scheme.primary
                            : scheme.outline,
                        size: 22,
                      ),
                  ],
                ),
              ),
              if (onEdit != null || onRotate != null || onRemove != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Crop / filter page ${i + 1}',
                        icon: const Icon(Icons.crop_rounded, size: 19),
                        onPressed: () => onEdit!(i),
                      ),
                    if (onRotate != null)
                      IconButton(
                        tooltip: 'Rotate page ${i + 1}',
                        icon: const ControlIcon(ControlGlyph.rotate, size: 26),
                        onPressed: () => onRotate!(i),
                      ),
                    if (onRemove != null)
                      IconButton(
                        tooltip: 'Remove page ${i + 1}',
                        icon: const ControlIcon(ControlGlyph.delete, size: 26),
                        onPressed: () => onRemove!(i),
                      ),
                  ],
                )
              else
                const SizedBox(height: 10),
            ],
          ),
        ),
      );
      return DragTarget<int>(
        key: ValueKey(identity(i)),
        onWillAcceptWithDetails: (d) => d.data != i,
        onAcceptWithDetails: (d) => onMove(d.data, i),
        builder: (_, candidates, __) => AnimatedScale(
          scale: candidates.isEmpty ? 1 : 1.04,
          duration: const Duration(milliseconds: 140),
          child: LongPressDraggable<int>(
            data: i,
            maxSimultaneousDrags: 1,
            feedback: SizedBox(
              width: 125,
              height: 180,
              child: Opacity(opacity: .85, child: card),
            ),
            childWhenDragging: Opacity(opacity: .25, child: card),
            child: card,
          ),
        ),
      );
    },
  );
}

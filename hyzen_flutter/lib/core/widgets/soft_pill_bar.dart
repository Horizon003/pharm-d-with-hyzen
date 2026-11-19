import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'display_preferences.dart';

class SoftPillItem {
  const SoftPillItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.key,
    this.shortLabel,
  });
  final String label;
  final String? shortLabel;
  final Widget icon;
  final VoidCallback? onTap;
  final Key? key;
}

/// Fixed-size slots keep touch targets still while a single selection pill moves.
class SoftPillBar extends StatelessWidget {
  const SoftPillBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.showAllLabels = false,
  });
  final List<SoftPillItem> items;
  final int selectedIndex;
  final bool showAllLabels;
  @override
  Widget build(BuildContext context) {
    assert(items.length > 1);
    final density = UiDensity.of(context);
    return Material(
      color: const Color(0xFFF0F0F2),
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFE0DEE5))),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, box) {
            final slot = box.maxWidth / items.length;
            final selected = selectedIndex.clamp(0, items.length - 1);
            final height = showAllLabels
                ? (44 * density + MediaQuery.textScalerOf(context).scale(11))
                      .clamp(50.0, double.infinity)
                : (48 * density).clamp(48.0, 56.0);
            final labels =
                showAllLabels ||
                (slot >= 64 &&
                    MediaQuery.textScalerOf(context).scale(9) <= 9 * 1.3);
            return SizedBox(
              height: height,
              child: Stack(
                children: [
                  Row(
                    children: [
                      for (final _ in items)
                        SizedBox(
                          width: slot,
                          height: height,
                          child: Center(
                            child: SizedBox.square(
                              dimension: (slot - 4).clamp(0.0, height - 4),
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (selectedIndex >= 0)
                    AnimatedAlign(
                      alignment: Alignment(
                        -1 + selected * 2 / (items.length - 1),
                        0,
                      ),
                      duration: HMotion.duration(
                        context,
                        const Duration(milliseconds: 220),
                      ),
                      curve: Curves.easeOutCubic,
                      child: SizedBox(
                        width: slot,
                        height: height,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFF17161D),
                              borderRadius: BorderRadius.all(
                                Radius.circular(28),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        SizedBox(
                          width: slot,
                          height: height,
                          child: Semantics(
                            key: items[i].key,
                            button: true,
                            enabled: items[i].onTap != null,
                            selected: i == selectedIndex,
                            label: items[i].label,
                            onTap: items[i].onTap,
                            child: Tooltip(
                              message: items[i].label,
                              excludeFromSemantics: true,
                              child: ExcludeSemantics(
                                child: _SoftSlot(
                                  item: items[i],
                                  selected: i == selectedIndex,
                                  labels: labels,
                                  showAllLabels: showAllLabels,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SoftSlot extends StatefulWidget {
  const _SoftSlot({
    required this.item,
    required this.selected,
    required this.labels,
    required this.showAllLabels,
  });
  final SoftPillItem item;
  final bool selected, labels, showAllLabels;
  @override
  State<_SoftSlot> createState() => _SoftSlotState();
}

class _SoftSlotState extends State<_SoftSlot> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: widget.item.onTap,
    customBorder: const StadiumBorder(),
    onHighlightChanged: (value) => setState(() => _pressed = value),
    child: AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .97 : 1,
      duration: HMotion.duration(context, HMotion.fast),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: HMotion.duration(context),
            curve: Curves.easeOutCubic,
            alignment:
                widget.labels && (widget.selected || widget.showAllLabels)
                ? const Alignment(0, -.43)
                : Alignment.center,
            child: Opacity(
              opacity: widget.item.onTap == null ? .4 : 1,
              child: widget.item.icon,
            ),
          ),
          if (widget.labels)
            Positioned(
              bottom: 4,
              left: 3,
              right: 3,
              child: AnimatedOpacity(
                duration: HMotion.duration(context),
                opacity: widget.item.onTap == null
                    ? .5
                    : (widget.selected || widget.showAllLabels ? 1 : 0),
                child: Text(
                  widget.item.shortLabel ?? widget.item.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: widget.selected
                        ? Colors.white
                        : const Color(0xFF3D3B44),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

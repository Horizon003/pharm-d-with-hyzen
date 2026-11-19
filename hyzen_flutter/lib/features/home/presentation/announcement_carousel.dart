import 'package:flutter/material.dart';
import '../../../core/widgets/refinement_art.dart';
import '../../../core/utils/links.dart';
import '../../content/domain/site_models.dart';

/// Uses published content only; keeps the legacy one-announcement format valid.
class AnnouncementCarousel extends StatefulWidget {
  const AnnouncementCarousel({super.key, required this.slides});
  final List<Announcement> slides;
  @override
  State<AnnouncementCarousel> createState() => _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<AnnouncementCarousel> {
  int page = 0;
  void move(int delta) => setState(() {
    page = (page + delta) % widget.slides.length;
  });
  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    page = page.clamp(0, widget.slides.length - 1);
    final scheme = Theme.of(context).colorScheme;
    final slide = widget.slides[page];
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final speed = details.primaryVelocity ?? 0;
        if (speed.abs() > 50) move(speed < 0 ? 1 : -1);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xfffff1df), Color(0xfff5eef9)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: RefinementArt(RefinementGlyph.announcement, size: 56),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slide.raw['category']?.toString().trim().isNotEmpty ==
                                true
                            ? slide.raw['category'].toString()
                            : 'Announcement',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slide.text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (slide.linkUrl.isNotEmpty)
                        TextButton(
                          onPressed: () => openLink(context, slide.linkUrl),
                          child: Text(
                            slide.linkText.isEmpty ? 'Open' : slide.linkText,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.slides.length > 1)
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous announcement',
                    onPressed: () => move(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${page + 1} / ${widget.slides.length}',
                      textAlign: TextAlign.center,
                      semanticsLabel:
                          'Announcement ${page + 1} of ${widget.slides.length}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next announcement',
                    onPressed: () => move(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

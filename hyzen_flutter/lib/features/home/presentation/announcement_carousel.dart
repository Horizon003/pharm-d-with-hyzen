import 'package:flutter/material.dart';
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final slide = widget.slides[page];
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final speed = details.primaryVelocity ?? 0;
        if (speed.abs() > 50) move(speed < 0 ? 1 : -1);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF142C34) : const Color(0xFFDCEEF5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: dark ? const Color(0xFF2B454F) : const Color(0xFFABC8D5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.campaign_rounded, size: 30),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slide.text,
                        style: const TextStyle(
                          fontSize: 13,
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

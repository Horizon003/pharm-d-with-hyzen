import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../content/data/content_providers.dart';
import '../../../core/utils/links.dart';
import '../../../app/safe_nav.dart';

/// Account overlay promotions. Admin-managed image slots are rendered first;
/// the existing catalog/offline cards remain as a safe fallback.
class ProfilePromotions extends ConsumerStatefulWidget {
  const ProfilePromotions({super.key});

  @override
  ConsumerState<ProfilePromotions> createState() => _ProfilePromotionsState();
}

class _Promotion {
  const _Promotion({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.image,
    this.route,
    this.admin = false,
  });

  final String title, subtitle;
  final IconData icon;
  final String? image, route;
  final bool admin;
}

class _ProfilePromotionsState extends ConsumerState<ProfilePromotions> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(siteSettingsProvider);
    final products = ref
        .watch(productsProvider)
        .valueOrNull
        ?.data
        .where((p) => !p.hidden)
        .take(5)
        .toList();
    final slides = <_Promotion>[
      for (final ad in settings.accountAds)
        _Promotion(
          title: ad.title,
          subtitle: ad.subtitle,
          image: ad.imageUrl,
          route: ad.route,
          icon: Icons.campaign_outlined,
          admin: true,
        ),
      if (products != null)
        for (final product in products)
          _Promotion(
            title: product.name,
            subtitle: '${settings.currency} ${product.price}',
            icon: Icons.shopping_bag_outlined,
            image: product.image,
            route: '/shop/p/${product.id}',
          ),
      if (products == null || products.isEmpty)
        _Promotion(
          title: 'Pharm-D essentials',
          subtitle: settings.shopComingSoon
              ? 'Discover what is coming'
              : 'Tools for your study journey',
          icon: Icons.shopping_bag_outlined,
          route: '/shop',
        ),
      const _Promotion(
        title: 'Your offline library',
        subtitle: 'Keep your notes within reach',
        icon: Icons.download_done_rounded,
        route: '/downloads',
      ),
    ];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: slides.any((s) => s.image?.isNotEmpty == true)
              ? 16 / 9
              : 3.2 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          child: PageView.builder(
            itemCount: slides.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              final slide = slides[index];
              final overlay =
                  theme.brightness == Brightness.dark ||
                  (slide.image != null && slide.image!.isNotEmpty);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: slide.route == null || slide.route!.isEmpty
                        ? null
                        : () {
                            if (slide.route!.startsWith('/')) {
                              context.open(slide.route!);
                            } else {
                              openLink(context, slide.route!);
                            }
                          },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (slide.image != null && slide.image!.isNotEmpty)
                          Image.network(
                            slide.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                overlay ? Colors.transparent : Colors.white,
                                overlay
                                    ? Colors.black.withValues(alpha: .78)
                                    : const Color(0xFFF0F2F3),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (slide.admin)
                                const Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              const SizedBox(height: 3),
                              Text(
                                slide.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: overlay
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (slide.subtitle.isNotEmpty)
                                Text(
                                  slide.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: overlay
                                        ? Colors.white70
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (slide.image == null || slide.image!.isEmpty)
                          Positioned(
                            right: 18,
                            top: 18,
                            child: Icon(
                              slide.icon,
                              size: 42,
                              color: overlay
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: overlay
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < slides.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == _page
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

import 'youtube.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common.dart';

/// Maps legacy website hash routes (`#/notes`, `#/shop` …) to app routes.
String? appRouteForLegacyHash(String url) {
  if (!url.startsWith('#/')) return null;
  final seg = url.substring(2).split('/').first.split('?').first;
  return switch (seg) {
    '' || 'home' => '/home',
    'notes' => '/study/notes',
    'mcqs' => '/study/mcqs',
    'papers' || 'pastpapers' => '/study/papers',
    'special' => '/study/special',
    'lectures' => '/lectures',
    'shop' => '/shop',
    'cart' => '/cart',
    'blog' => '/blog',
    'about' => '/about',
    'contact' => '/contact',
    'account' => '/profile',
    _ => '/home',
  };
}

Future<void> openLink(BuildContext context, String url) async {
  final u = url.trim();
  if (u.isEmpty) return;
  final internal = appRouteForLegacyHash(u);
  if (internal != null) {
    context.go(internal);
    return;
  }
  if (youtubeEmbedUri(u) != null) {
    context.push('/lecture-player', extra: {'title': 'Lecture', 'url': u});
    return;
  }
  var target = u;
  if (!target.contains('://') &&
      !target.startsWith('mailto:') &&
      !target.startsWith('tel:')) {
    target = 'https://$target';
  }
  final uri = Uri.tryParse(target);
  if (uri == null ||
      !(uri.isScheme('https') ||
          uri.isScheme('http') ||
          uri.isScheme('mailto') ||
          uri.isScheme('tel'))) {
    if (context.mounted) {
      showHSnack(context, 'This link can\u2019t be opened.', error: true);
    }
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showHSnack(context, 'Couldn’t open the link.', error: true);
    }
  } catch (_) {
    if (context.mounted) {
      showHSnack(context, 'Couldn’t open the link.', error: true);
    }
  }
}

String whatsappUrl(String number) =>
    'https://wa.me/${number.replaceAll(RegExp(r'[^0-9]'), '')}';

import 'package:flutter/material.dart';

/// Use the student photo when available, otherwise show initials.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 32,
    this.fallback = 'H',
  });

  final String? photoUrl;
  final double radius;
  final String fallback;

  static String? resolveUrl(String? profile, [String? account]) {
    for (final value in [profile, account]) {
      final trimmed = value?.trim();
      final uri = Uri.tryParse(trimmed ?? '');
      if (uri?.scheme == 'https' && uri!.host.isNotEmpty) return trimmed;
    }
    return null;
  }

  static ImageProvider? imageFor(String? value) {
    final url = resolveUrl(value);
    return url == null ? null : NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final image = imageFor(photoUrl);
    return CircleAvatar(
      radius: radius,
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, __) {},
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        fallback.isEmpty ? 'H' : fallback[0].toUpperCase(),
        style: TextStyle(
          fontSize: radius * .8,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

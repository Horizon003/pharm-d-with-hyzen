/// Accept only official YouTube video/playlist forms; never interpolate raw URLs
/// into HTML or pass arbitrary script/file schemes to an embedded player.
Uri? youtubeEmbedUri(String input) {
  final raw = input.trim();
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  if (uri == null || !['http', 'https'].contains(uri.scheme)) return null;
  final host = uri.host.toLowerCase();
  if (![
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
    'youtu.be',
    'www.youtu.be',
  ].contains(host)) {
    return null;
  }
  final parts = uri.pathSegments;
  String? id;
  if (host.endsWith('youtu.be') && parts.isNotEmpty) {
    id = parts.first;
  } else if (parts.isNotEmpty &&
      ['embed', 'shorts', 'live', 'v'].contains(parts.first) &&
      parts.length > 1) {
    id = parts[1];
  } else {
    id = uri.queryParameters['v'];
  }
  final list = uri.queryParameters['list'];
  final validId = id != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id);
  final validList =
      list != null && RegExp(r'^[a-zA-Z0-9_-]{8,120}$').hasMatch(list);
  if (!validId && !validList) return null;
  final start = int.tryParse(
    uri.queryParameters['start'] ?? uri.queryParameters['t'] ?? '',
  );
  return Uri.https(
    'www.youtube-nocookie.com',
    '/embed/${validId ? id : 'videoseries'}',
    {
      'playsinline': '1',
      'rel': '0',
      'enablejsapi': '0',
      if (validList) 'list': list,
      if (start != null && start >= 0) 'start': '$start',
    },
  );
}

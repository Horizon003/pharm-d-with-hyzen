import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/core/utils/youtube.dart';

void main() {
  test('official YouTube forms stay in the embedded player', () {
    for (final input in [
      'https://youtu.be/M7lc1UVf-VE',
      'youtube.com/watch?v=M7lc1UVf-VE',
      'https://m.youtube.com/shorts/M7lc1UVf-VE',
      'https://www.youtube.com/live/M7lc1UVf-VE',
      'https://www.youtube-nocookie.com/embed/M7lc1UVf-VE',
    ]) {
      final uri = youtubeEmbedUri(input)!;
      expect(uri.host, 'www.youtube-nocookie.com');
      expect(uri.path, '/embed/M7lc1UVf-VE');
      expect(uri.queryParameters['playsinline'], '1');
    }
  });
  test('playlist links and timestamps are preserved', () {
    final uri = youtubeEmbedUri(
      'https://youtube.com/playlist?list=PLabcdefghijk12345',
    )!;
    expect(uri.path, '/embed/videoseries');
    expect(uri.queryParameters['list'], 'PLabcdefghijk12345');
    expect(
      youtubeEmbedUri(
        'https://youtu.be/M7lc1UVf-VE?t=120',
      )!.queryParameters['start'],
      '120',
    );
  });
  test('unknown hosts and script injection never enter an embedded page', () {
    for (final raw in [
      'javascript:alert(1)',
      'https://youtube.com.evil.test/watch?v=M7lc1UVf-VE',
      'https://youtube.com@evil.test/watch?v=M7lc1UVf-VE',
      'file:///etc/passwd',
      'https://youtube.com/watch?v=%22%3E%3Cscript',
      'https://example.org/video',
    ]) {
      expect(youtubeEmbedUri(raw), isNull, reason: raw);
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/core/widgets/profile_avatar.dart';

void main() {
  test(
    'missing or retired avatar shows initials rather than an unrelated panda',
    () {
      for (final value in [
        null,
        '',
        'avatar:male_1',
        'avatar:female_1',
        'https://',
      ]) {
        expect(ProfileAvatar.imageFor(value), isNull);
      }
    },
  );
  test('saved uploaded photo takes priority over the account photo', () {
    expect(
      ProfileAvatar.resolveUrl(
        ' https://example.org/upload.jpg ',
        'https://example.org/google.jpg',
      ),
      'https://example.org/upload.jpg',
    );
    expect(
      ProfileAvatar.imageFor('https://example.org/photo.jpg'),
      isA<NetworkImage>(),
    );
  });
  test('missing and legacy profile values resolve to the account photo', () {
    for (final value in [null, '', 'avatar:male_1']) {
      expect(
        ProfileAvatar.resolveUrl(value, 'https://example.org/google.jpg'),
        'https://example.org/google.jpg',
      );
    }
  });
  testWidgets('empty profile photo renders initials without image errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfileAvatar(photoUrl: null, fallback: 'Ali')),
    );
    expect(find.text('A'), findsOneWidget);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}

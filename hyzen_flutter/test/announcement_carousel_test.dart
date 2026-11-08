import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/content/domain/site_models.dart';
import 'package:hyzen_pharmd/features/home/presentation/announcement_carousel.dart';

void main() {
  testWidgets('published slides navigate and content removal stays safe', (
    tester,
  ) async {
    final slides = [
      Announcement({'enabled': true, 'text': 'First published announcement'}),
      Announcement({'enabled': true, 'text': 'Second published announcement'}),
    ];
    Future<void> render(List<Announcement> values) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AnnouncementCarousel(slides: values)),
      ),
    );
    await render(slides);
    expect(find.text('First published announcement'), findsOneWidget);
    await tester.tap(find.byTooltip('Next announcement'));
    await tester.pump();
    expect(find.text('Second published announcement'), findsOneWidget);
    await render(slides.take(1).toList());
    expect(find.text('First published announcement'), findsOneWidget);
    await render([]);
    expect(find.text('First published announcement'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

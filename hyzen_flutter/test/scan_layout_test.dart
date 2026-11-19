import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/core/theme/app_theme.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/office_ui.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/scan_pdf_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.hyzen.pharmd/camera_pages');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory folder;
  late List<String> pages;
  setUpAll(() async {
    final fonts = FontLoader('Outfit');
    for (final weight in [400, 500, 600, 700]) {
      fonts.addFont(rootBundle.load('assets/fonts/Outfit-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    folder = await Directory.systemTemp.createTemp('scan-layout-');
    pages = [for (var i = 0; i < 2; i++) '${folder.path}/page-$i.png'];
    for (final path in pages) {
      await File('test/fixtures/scan-page.png').copy(path);
      expect(await OfficeImageCache.image(path), isNotNull);
    }
  });
  tearDownAll(() => folder.delete(recursive: true));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  testWidgets(
    'review and free corners fit small screens with large text',
    (tester) async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'pageInfo' => {
            'original': pages.first,
            'quad': [.12, .16, .9, .1, .86, .92, .08, .88],
          },
          _ => pages,
        },
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final dark in [false, true]) {
        for (final width in [390.0, 320.0]) {
          for (final scale in [1.0, 2.0]) {
            tester.view.physicalSize = Size(width, 844);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  theme: dark ? AppTheme.dark() : AppTheme.light(),
                  home: const ScanPdfScreen(),
                ),
              ),
            );
            for (var frame = 0; frame < 4; frame++) {
              await tester.pump();
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 80)),
              );
            }
            await tester.pumpAndSettle();
            expect(find.text('Page 1 of 2'), findsOneWidget);
            expect(tester.takeException(), isNull);
            if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
              await expectLater(
                find.byType(Scaffold),
                matchesGoldenFile(
                  '../qa/compact-office/${dark ? 'dark' : 'light'}-review-${width.toInt()}-$scale.png',
                ),
              );
            }
            await tester.tap(find.text('Crop'));
            for (var frame = 0; frame < 4; frame++) {
              await tester.pump();
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 80)),
              );
            }
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('crop-handle-0')), findsOneWidget);
            expect(tester.takeException(), isNull);
            if (const bool.fromEnvironment('HYZEN_CAPTURE_QA') &&
                scale == 1 &&
                width == 390) {
              await expectLater(
                find.byType(Scaffold),
                matchesGoldenFile(
                  '../qa/compact-office/${dark ? 'dark' : 'light'}-corners.png',
                ),
              );
            }
          }
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/app/providers.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/studio_annotation_screen.dart';
import 'package:hyzen_pharmd/features/pdf_studio/data/studio_file_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/core/theme/app_theme.dart';
import 'package:hyzen_pharmd/core/widgets/polish_ui.dart';
import 'package:hyzen_pharmd/core/widgets/workspace_icons.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/page_grid.dart';
import 'package:hyzen_pharmd/features/viewer/reader_chrome.dart';
import 'package:hyzen_pharmd/features/auth/presentation/login_screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Outfit');
    for (final weight in [400, 500, 600, 700]) {
      fonts.addFont(rootBundle.load('assets/fonts/Outfit-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets(
    'compact reader actions keep document geometry and do not toggle chrome',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var shared = 0, downloaded = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ReaderScaffold(
            title: 'Pharmacology lecture notes long filename.pdf',
            onShare: () => shared++,
            onDownload: () => downloaded++,
            actions: const [],
            child: const ColoredBox(color: Colors.white),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controls = tester.widgetList<ControlIcon>(find.byType(ControlIcon));
      expect(controls.map((icon) => icon.glyph), [
        ControlGlyph.back,
        ControlGlyph.share,
        ControlGlyph.download,
        ControlGlyph.more,
      ]);
      expect(
        controls.every((icon) => icon.color == const Color(0xFF25242A)),
        isTrue,
      );
      final page = find.byKey(const ValueKey('reader-page-surface'));
      final geometry = tester.getRect(page);
      await tester.tap(find.byTooltip('Share'));
      await tester.tap(find.byTooltip('Download'));
      expect(shared, 1);
      expect(downloaded, 1);
      expect(
        find.text('Pharmacology lecture notes long filename.pdf'),
        findsOneWidget,
      );
      await tester.tapAt(geometry.center);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Share'), findsNothing);
      expect(tester.getRect(page), geometry);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('small glass artwork keeps a 48dp touch target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HGlassButton(
              icon: 'icon-search',
              label: 'Search',
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byType(HGlassButton);
    expect(tester.getSize(target), const Size(48, 48));
    await tester.tapAt(tester.getTopLeft(target) + const Offset(4, 24));
    expect(taps, 1);
  });
  testWidgets(
    'notification count fits outside the glass and announces its full value',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
              child: Center(
                child: HGlassButton(
                  icon: 'icon-bell',
                  label: 'Notifications',
                  badge: 12,
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );

      final button = find.byTooltip('Notifications');
      final badge = find.text('9+');
      final target = tester.getRect(button);
      final count = tester.getRect(badge);
      final glass = tester.getRect(find.byType(ClipOval));
      expect(target.size, const Size.square(48));
      expect(target.contains(count.topLeft), isTrue);
      expect(target.contains(count.bottomRight), isTrue);
      expect(count.top, lessThan(glass.top));
      expect(count.height, closeTo(10, 2));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Notifications')),
        matchesSemantics(
          label: 'Notifications',
          value: '12 unread',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.tapAt(count.center);
      expect(taps, 1);
      semantics.dispose();
    },
  );

  testWidgets(
    'organize pages exposes generated rotate and remove controls at 320dp',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageGrid(
              count: 2,
              image: (_) => const ColoredBox(color: Colors.white),
              identity: (i) => i,
              onMove: (_, _) {},
              onEdit: (i) => actions.add('crop $i'),
              onRotate: (i) => actions.add('rotate $i'),
              onRemove: (i) => actions.add('remove $i'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rotate = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Rotate page 2',
      );
      final remove = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Remove page 1',
      );
      expect(
        tester.widget<IconButton>(rotate).icon,
        isA<ControlIcon>().having(
          (icon) => icon.glyph,
          'glyph',
          ControlGlyph.rotate,
        ),
      );
      expect(
        tester.widget<IconButton>(remove).icon,
        isA<ControlIcon>().having(
          (icon) => icon.glyph,
          'glyph',
          ControlGlyph.delete,
        ),
      );
      await tester.tap(rotate);
      await tester.tap(remove);
      expect(actions, ['rotate 1', 'remove 0']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'editor dock retains every tool at narrow width with large text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final studyPrefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const channel = MethodChannel('com.hyzen.pharmd/pdf_studio');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final bytes = File('test/fixtures/scan-page.png').readAsBytesSync();
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'pageCount' => 1,
          'getEditState' => '{}',
          'renderPage' => {'bytes': bytes, 'width': 600, 'height': 800},
          _ => null,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPrefsProvider.overrideWithValue(studyPrefs)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: StudioAnnotationScreen(
              file: StudioFileItem(
                id: 'fixture',
                originalFileName: 'Notes.pdf',
                displayName: 'Notes.pdf',
                internalFilePath: '/fixture.pdf',
                editStateJsonPath: '/fixture.json',
                sourceType: 'imported',
                fileCategory: 'PDF',
                fileSizeBytes: 100,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Page 1 / 1'), findsOneWidget);
      await tester.tap(find.byTooltip('More edit tools'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      final toolList = find.descendant(
        of: sheet,
        matching: find.byType(Scrollable),
      );
      Finder tool(String name) =>
          find.descendant(of: sheet, matching: find.text(name));
      for (final name in [
        'select',
        'arrow',
        'note',
        'ink',
        'highlight',
        'underline',
        'strike',
        'rectangle',
        'circle',
        'text',
        'signature',
      ]) {
        await tester.scrollUntilVisible(tool(name), 100, scrollable: toolList);
        expect(tool(name), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        tool('highlight'),
        -100,
        scrollable: toolList,
      );
      await tester.tap(tool('highlight'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../qa/reference/after/editor-dock-large-text.png'),
        );
      }
    },
  );
  if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
    testWidgets('workspace reader and account choice visual QA', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final entry in <String, Widget>{
        'reader-glass': ReaderScaffold(
          title: 'Pharmacology notes.pdf',
          onShare: () {},
          onDownload: () {},
          actions: const [],
          child: const ColoredBox(
            color: Color(0xFFF8F6F2),
            child: Center(
              child: Text(
                'Document preview',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ),
        'account-choice': AccountChoiceScreen(onLogin: () {}),
      }.entries) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: entry.value,
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../qa/reference/after/${entry.key}.png'),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}

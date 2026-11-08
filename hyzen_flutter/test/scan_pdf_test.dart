import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hyzen_pharmd/features/pdf_studio/data/studio_storage.dart';
import 'package:hyzen_pharmd/features/pdf_studio/data/pdf_studio_repository.dart';
import 'package:hyzen_pharmd/core/storage/local_store.dart';
import 'package:hyzen_pharmd/features/pdf_studio/data/studio_pdf_engine.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/scan_pdf_screen.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/rich_document_screen.dart';

class _ScanStorage implements StudioStorage {
  @override
  Future<StoredStudioFile> importCopy(String sourcePath, String id) async =>
      StoredStudioFile(
        path: '/private/$id.pdf',
        editStatePath: '/private/${id}_state.json',
        sizeBytes: 1234,
        extension: 'pdf',
      );
  @override
  Future<bool> exists(String path) async => true;
  @override
  Future<void> deleteStored({
    required String path,
    required String editStatePath,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const camera = MethodChannel('com.hyzen.pharmd/camera_pages');
  const pdf = MethodChannel('com.hyzen.pharmd/pdf_studio');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  setUp(() async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.hyzen.pharmd/document_scanner'),
      (_) async => await camera.invokeListMethod<String>('capture'),
    );
    directory = await Directory.systemTemp.createTemp('hyzen-scan-test-');
    Hive.init(directory.path);
    await Hive.openBox<String>(Boxes.pdfStudioHistory);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.hyzen.pharmd/document_scanner'),
      null,
    );
    messenger.setMockMethodCallHandler(camera, null);
    messenger.setMockMethodCallHandler(pdf, null);
    await Hive.close();
    await directory.delete(recursive: true);
  });
  testWidgets(
    'native multi-page scanner returns to a usable page grid',
    (tester) async {
      var scanned = false;
      messenger.setMockMethodCallHandler(camera, (_) async => <String>[]);
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.hyzen.pharmd/document_scanner'),
        (call) async {
          scanned = call.method == 'scan';
          return ['/tmp/scanned-one.jpg', '/tmp/scanned-two.jpg'];
        },
      );
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ScanPdfScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(scanned, isTrue);
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(find.text('Crop'), findsOneWidget);
      expect(find.text('Rotate'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-more')), findsOneWidget);
      expect(find.text('Keep scanning'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'cancelled capture leaves an empty draft and disabled save',
    (tester) async {
      messenger.setMockMethodCallHandler(camera, (_) async => <String>[]);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ScanPdfScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.text('Add your first page'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('save-scan-pdf')))
            .onPressed,
        isNull,
      );
      expect(Hive.box<String>(Boxes.pdfStudioHistory).isEmpty, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'each confirmed camera capture appends another page',
    (tester) async {
      final pages = <String>[];
      messenger.setMockMethodCallHandler(camera, (call) async {
        if (call.method == 'capture') pages.add('/tmp/page${pages.length}.jpg');
        return [...pages];
      });
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ScanPdfScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scan-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scan-more')));
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of 2'), findsOneWidget);
      // Numbered thumbnail badges in the page strip.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'restored camera draft survives a recreated Flutter screen',
    (tester) async {
      messenger.setMockMethodCallHandler(
        camera,
        (_) async => ['/tmp/one.jpg', '/tmp/two.jpg'],
      );
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ScanPdfScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ScanPdfScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'camera error preserves gallery action and existing pages',
    (tester) async {
      messenger.setMockMethodCallHandler(camera, (call) async {
        if (call.method == 'capture') {
          throw PlatformException(
            code: 'camera',
            message: 'Choose gallery images instead.',
          );
        }
        return ['/tmp/one.jpg'];
      });
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ScanPdfScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scan-more')));
      await tester.pumpAndSettle();
      expect(find.text('Choose gallery images instead.'), findsOneWidget);
      expect(find.text('Add Images'), findsOneWidget);
      expect(find.text('Auto detect'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  test(
    'layered and flattened operations reach distinct native modes',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(pdf, (call) async {
        calls.add(call);
        return '/tmp/result.pdf';
      });
      await StudioPdfEngine.compose([StudioPage('/tmp/a.pdf', 0)]);
      await StudioPdfEngine.compose([
        StudioPage('/tmp/a.pdf', 0),
      ], flatten: true);
      expect(calls[0].arguments['flatten'], isFalse);
      expect(calls[1].arguments['flatten'], isTrue);
    },
  );
  testWidgets(
    'saving validates page count, commits history, then clears draft',
    (tester) async {
      final events = <String>[];
      messenger.setMockMethodCallHandler(camera, (call) async {
        events.add(call.method);
        return call.method == 'clear' ? true : ['/tmp/one.jpg'];
      });
      messenger.setMockMethodCallHandler(pdf, (call) async {
        events.add(call.method);
        return call.method == 'pageCount' ? 1 : '/tmp/scan.pdf';
      });
      final container = ProviderContainer(
        overrides: [studioStorageProvider.overrideWithValue(_ScanStorage())],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (c, _) => Scaffold(
              body: TextButton(
                onPressed: () => c.push('/create-pdf'),
                child: const Text('Create'),
              ),
            ),
          ),
          GoRoute(
            path: '/create-pdf',
            builder: (_, __) => const ScanPdfScreen(),
          ),
          GoRoute(
            path: '/pdf-studio/viewer/:id',
            builder: (_, __) => const Scaffold(body: Text('Saved PDF opened')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-scan-pdf')));
      await tester.pumpAndSettle();
      expect(find.text('File name'), findsOneWidget);
      await tester.tap(find.text('Save'));
      // Hive completes real IO, while route/provider callbacks run in the
      // test clock. Let both advance until the durable commit completes.
      for (var i = 0; i < 100 && !events.contains('clear'); i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(events, contains('clear'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Open PDF'))).pop('open');
      await tester.pump(const Duration(milliseconds: 500));
      final saved = container.read(pdfStudioHistoryProvider).single;
      expect(saved.operationBadge, 'SCANNED');
      expect(saved.pageCount, 1);
      expect(saved.displayName, startsWith('Scan '));
      expect(saved.displayName, endsWith('.pdf'));
      expect(events.indexOf('clear'), greaterThan(events.indexOf('pageCount')));
      expect(tester.takeException(), isNull);
      // Drain Hive's asynchronous writer while the widget test clock still runs.
      var closed = false;
      final closing = Hive.close().then((_) => closed = true);
      for (var i = 0; i < 100 && !closed; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(closed, isTrue);
      await closing;
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'failed PDF save never clears the captured draft',
    (tester) async {
      var cleared = false;
      messenger.setMockMethodCallHandler(camera, (call) async {
        if (call.method == 'clear') cleared = true;
        return ['/tmp/page.jpg'];
      });
      messenger.setMockMethodCallHandler(
        pdf,
        (_) async => throw PlatformException(code: 'save'),
      );
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ScanPdfScreen())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-scan-pdf')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(cleared, isFalse);
      expect(find.text('Auto detect'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'document writer supports narrow phone formatting blocks',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RichDocumentScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Document writer'), findsOneWidget);
      expect(find.byTooltip('Bold'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

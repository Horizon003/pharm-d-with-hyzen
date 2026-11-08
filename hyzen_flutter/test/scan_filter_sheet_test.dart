import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/scan_filter_sheet.dart';

void main() {
  const channel = MethodChannel('com.hyzen.pharmd/camera_pages');
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final confirm in [true, false]) {
    testWidgets(
      'filter preview ${confirm ? 'confirms all pages' : 'cancels without mutation'}',
      (tester) async {
        final calls = <MethodCall>[];
        ScanFilterChoice? choice;
        final bytes = File('test/fixtures/scan-page.png').readAsBytesSync();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'pageInfo') return {'filter': 'original'};
          if (call.method == 'preview') return bytes;
          throw StateError('Unexpected mutation: ${call.method}');
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    choice = await showModalBottomSheet<ScanFilterChoice>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const ScanFilterSheet(
                        path: '/draft/page.jpg',
                        multiple: true,
                      ),
                    );
                  },
                  child: const Text('Open filters'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open filters'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Grayscale'));
        await tester.pumpAndSettle();
        expect(find.byType(ScanFilterSheet), findsOneWidget);
        expect(calls.last.arguments['filter'], 'gray');
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byTooltip(confirm ? 'Confirm filter' : 'Cancel filters'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ScanFilterSheet), findsNothing);
        expect(
          calls.every((c) => c.method == 'pageInfo' || c.method == 'preview'),
          isTrue,
        );
        if (confirm) {
          expect(choice?.filter, 'gray');
          expect(choice?.all, isTrue);
        } else {
          expect(choice, isNull);
        }
      },
    );
  }
}

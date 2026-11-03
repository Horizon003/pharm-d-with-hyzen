import 'dart:io';
import 'package:hyzen_pharmd/features/home/presentation/home_screen.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_background.dart';
import 'package:hyzen_pharmd/features/home/data/recent_controller.dart';
import 'package:hyzen_pharmd/features/viewer/offline_pdf.dart';
import 'package:hyzen_pharmd/features/academics/presentation/discovery_widgets.dart';
import 'package:hyzen_pharmd/core/theme/tokens.dart';
import 'package:hyzen_pharmd/core/widgets/surfaces.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:hyzen_pharmd/features/auth/domain/student_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hyzen_pharmd/app/app.dart';
import 'package:hyzen_pharmd/core/widgets/main_dock.dart';
import 'package:hyzen_pharmd/features/downloads/data/downloads_controller.dart';
import 'package:hyzen_pharmd/features/downloads/domain/download_record.dart';
import 'package:hyzen_pharmd/features/profile/presentation/profile_screens.dart';
import 'package:hyzen_pharmd/features/profile/presentation/widgets/account_widgets.dart';
import 'package:hyzen_pharmd/app/providers.dart';
import 'package:hyzen_pharmd/app/router.dart';
import 'package:hyzen_pharmd/core/storage/local_store.dart';
import 'package:hyzen_pharmd/features/admin/domain/import_csv.dart';
import 'package:hyzen_pharmd/features/admin/data/admin_repository.dart';
import 'package:hyzen_pharmd/features/content/data/content_source.dart';
import 'package:hyzen_pharmd/features/content/data/content_providers.dart';
import 'package:hyzen_pharmd/features/academics/domain/models.dart';
import 'package:hyzen_pharmd/features/viewer/external_files.dart';
import 'package:hyzen_pharmd/core/widgets/rive_mascot.dart';
import 'package:hyzen_pharmd/core/widgets/common.dart';
import 'package:hyzen_pharmd/core/widgets/hyzen_art.dart';
import 'package:hyzen_pharmd/features/auth/presentation/splash_welcome_screens.dart';

class StudentUser extends Fake implements User {
  @override
  String get uid => 'student-test';
  @override
  String? get displayName => 'Test Student';
  @override
  String? get email => 'student@example.org';
  @override
  String? get photoURL => null;
}

void main() {
  late Directory temp;
  late SharedPreferences prefs;
  late ProviderContainer container;
  late List<Map<String, dynamic>> fixtureTree;
  setUpAll(() async {
    final fonts = FontLoader('Manrope');
    for (final weight in [400, 500, 600, 700, 800]) {
      fonts.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    temp = await Directory.systemTemp.createTemp('hyzen-widget-test-');
    Hive.init(temp.path);
    for (final box in [
      Boxes.contentCache,
      Boxes.downloads,
      Boxes.recent,
      Boxes.cart,
      Boxes.myOrders,
      Boxes.externalHistory,
      Boxes.pdfStudioHistory,
    ]) {
      await Hive.openBox<String>(box);
    }
    final tree = <Map<String, dynamic>>[];
    var id = 0;
    mergeRows(
      tree,
      validateImport(
        'kind,professional_year,semester,subject,section,topic,title,url,published\nnotes,2nd Professional,Semester 1,Pharmacology,Study Notes,Diabetes,Insulin Notes,https://example.org/a.pdf,true',
        'fixture.csv',
      ).rows,
      () => 'id-${id++}',
    );
    fixtureTree = tree;
    container = ProviderContainer(
      overrides: [
        homeClockProvider.overrideWithValue(() => DateTime(2026, 1, 1, 18)),
        sharedPrefsProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(StudentUser())),
        profileProvider.overrideWith(
          (ref) => Stream.value(
            const StudentProfile(
              uid: 'student-test',
              fullName: 'Ali Raza',
              mobile: '+923001234567',
              gender: 'male',
              city: 'Lahore',
              professionalYear: 2,
              institutionName: 'College of Pharmacy',
              affiliationStatus: AffiliationStatus.nonAffiliated,
              email: 'student@example.org',
            ),
          ),
        ),
        adminTreeProvider.overrideWith(
          (ref, kind) async => copyTree(tree, kind),
        ),
        contentProvider.overrideWith(
          (ref, key) => Stream.value(
            ContentSnapshot(
              value: key == 'pw_notes_tree'
                  ? tree
                  : key == 'pw_settings'
                  ? {'shopComingSoon': false}
                  : key == 'pw_announcement'
                  ? {'enabled': true, 'text': 'Test academic announcement'}
                  : key == 'pw_about'
                  ? {'about': '<p>Welcome to Hyzen</p>'}
                  : key == 'pw_blogs'
                  ? [
                      {
                        'id': 'b1',
                        'title': 'Student tips',
                        'status': 'published',
                        'contentHtml': '<p>Study consistently.</p>',
                      },
                    ]
                  : [],
              fromCache: false,
            ),
          ),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await Hive.close();
    await temp.delete(recursive: true);
  });
  Future<void> open(WidgetTester tester, String path) async {
    await tester.runAsync(
      () => Future.wait([
        for (final k in LibraryKind.values)
          container.read(parsedLibraryProvider(k).future),
      ]),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HyzenApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  test('HOME-03 time greeting boundaries', () {
    expect(homeGreeting(DateTime(2026, 1, 1, 6)), 'Good morning');
    expect(homeGreeting(DateTime(2026, 1, 1, 12)), 'Good afternoon');
    expect(homeGreeting(DateTime(2026, 1, 1, 17)), 'Good evening');
  });
  testWidgets(
    'HOME-01/02/03/04/05/17 adaptive atmosphere, personalized monochrome greeting',
    (tester) async {
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        container.read(themeModeProvider.notifier).set(mode);
        await open(tester, '/home');
        expect(find.byType(HomeAtmosphere), findsNWidgets(2));
        final greeting = tester.widget<Text>(
          find.byKey(const ValueKey('home-greeting')),
        );
        expect(greeting.data, 'GOOD EVENING');
        expect(greeting.style!.color, isNot(HColors.mint));
        expect(find.text('Welcome back, Ali'), findsOneWidget);
        final accountAction = tester.getSize(
          find.byTooltip('Profile & settings'),
        );
        expect(accountAction.width, greaterThanOrEqualTo(48));
        expect(accountAction.height, greaterThanOrEqualTo(48));
        expect(find.byKey(const ValueKey('home-hero-art')), findsOneWidget);
        expect(find.text('More from Hyzen'), findsNothing);
        expect(find.text('About Hyzen'), findsNothing);
        expect(find.text('Contact us'), findsNothing);
        final search = find.text('Search subjects, topics or files');
        expect(
          Theme.of(tester.element(search)).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('Light Home profile action preserves the light Account sheet', (
    tester,
  ) async {
    container.read(themeModeProvider.notifier).set(ThemeMode.light);
    await open(tester, '/home');
    await tester.tap(find.byTooltip('Profile & settings'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ProfileScreen))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Home announcement preference hides the supplied content', (
    tester,
  ) async {
    await open(tester, '/home');
    expect(find.text('Test academic announcement'), findsOneWidget);
    container.read(boolPrefProvider('pref_announcements').notifier).set(false);
    await tester.pumpAndSettle();
    expect(find.text('Test academic announcement'), findsNothing);
    expect(prefs.getBool('pref_announcements'), isFalse);
  });
  testWidgets(
    'Home Clear requires confirmation before changing recent history',
    (tester) async {
      final saved = File('${temp.path}/keep.pdf');
      await tester.runAsync(() async {
        await saved.writeAsString('%PDF-');
        await container
            .read(recentProvider.notifier)
            .touch(
              const FileRef(
                kind: LibraryKind.notes,
                title: 'Recent revision',
                url: 'https://example.org/recent.pdf',
              ),
            );
        await JsonBox(Boxes.downloads).put(
          'keep',
          DownloadRecord(
            key: 'keep',
            kind: LibraryKind.notes,
            title: 'Keep',
            sourceUrl: 'https://example.org/keep.pdf',
            status: DownloadStatus.ready,
            localPath: saved.path,
          ).toMap(),
        );
      });
      await open(tester, '/home');
      final clear = find.text('Clear');
      await Scrollable.ensureVisible(tester.element(clear), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(find.text('Clear recent history?'), findsOneWidget);
      expect(container.read(recentProvider), isNotEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(recentProvider), isNotEmpty);
      expect(container.read(downloadsProvider), contains('keep'));
      expect(await tester.runAsync(saved.exists), isTrue);
    },
  );
  testWidgets('HOME-07/08 real search and Quick Access routes', (tester) async {
    for (final entry in <String, String>{
      'Search subjects, topics or files': '/search',
      'Study Library': '/study',
      'Office Workspace': '/pdf-studio',
      'Downloads': '/downloads',
      'Shop': '/shop',
    }.entries) {
      await open(tester, '/home');
      final target = find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.text(entry.key),
          )
          .first;
      await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        entry.value,
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'HOME-09/15/16 real persisted download and recent providers feed Home',
    (tester) async {
      await tester.runAsync(() async {
        for (final entry in [
          DownloadRecord(
            key: 'active',
            kind: LibraryKind.notes,
            title: 'Active',
            sourceUrl: 'https://example.org/active.pdf',
            status: DownloadStatus.downloading,
          ),
          DownloadRecord(
            key: 'saved',
            kind: LibraryKind.notes,
            title: 'Saved',
            sourceUrl: 'https://example.org/saved.pdf',
            status: DownloadStatus.ready,
            localPath: '${temp.path}/saved.pdf',
            unopened: true,
          ),
        ]) {
          if (entry.localPath != null) {
            await File(entry.localPath!).writeAsString('%PDF-');
          }
          await JsonBox(Boxes.downloads).put(entry.key, entry.toMap());
        }
        await container
            .read(recentProvider.notifier)
            .touch(
              const FileRef(
                kind: LibraryKind.notes,
                title: 'Actual recent notes',
                url: 'https://example.org/recent.pdf',
              ),
            );
      });
      await open(tester, '/home');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 Saved'), findsOneWidget);
      expect(find.text('1 New'), findsOneWidget);
      expect(
        find.text('1 Downloading'),
        findsNothing,
        reason: 'Interrupted transfers restore as paused',
      );
      expect(find.text('Actual recent notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'HOME-06/13/14/16 responsive Home supports long content and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(
        () => container
            .read(recentProvider.notifier)
            .touch(
              const FileRef(
                kind: LibraryKind.notes,
                title:
                    'A very long pharmaceutical chemistry examination revision filename for the second professional year',
                url: 'https://example.org/long.pdf',
              ),
            ),
      );
      await open(tester, '/home');
      final subjects = tester.widget<SubjectDiscovery>(
        find.byType(SubjectDiscovery),
      );
      expect(subjects.compact, isTrue);
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(HCard), findsWidgets);
    },
  );
  testWidgets('HOME-18 About, Contact and Blog routes remain available', (
    tester,
  ) async {
    for (final path in ['/about', '/contact', '/blog']) {
      await open(tester, path);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        path,
      );
      expect(find.text('This page could not be found'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'HOME-11 renderer reports success once and never for a failed open',
    (tester) async {
      final file = File('${temp.path}/readable.txt');
      await tester.runAsync(
        () => file.writeAsString('Readable saved academic notes'),
      );
      var opened = 0;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: OfflinePdf(path: file.path, onOpened: () => opened++),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.text('Readable saved academic notes'), findsOneWidget);
      expect(opened, 1);
      await tester.pumpAndSettle();
      expect(opened, 1);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: OfflinePdf(
              key: const ValueKey('missing'),
              path: '${temp.path}/missing.txt',
              onOpened: () => opened++,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.text('Could not read this document.'), findsOneWidget);
      expect(opened, 1);
    },
  );
  testWidgets(
    'announcement toggle persists between settings and account info',
    (tester) async {
      await open(tester, '/settings');
      await tester.ensureVisible(find.byType(AccountToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AccountToggle));
      await tester.pumpAndSettle();
      expect(prefs.getBool('pref_announcements'), isFalse);
      container.read(routerProvider).go('/profile/info');
      await tester.pumpAndSettle();
      expect(
        tester.widget<AccountToggle>(find.byType(AccountToggle)).value,
        isFalse,
      );
      final email = tester.widget<SettingsRow>(
        find.byWidgetPredicate((w) => w is SettingsRow && w.title == 'Email'),
      );
      expect(email.value, 'student@example.org');
      expect(email.onTap, isNull);
      await tester.ensureVisible(find.text('Change Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change Photo'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account surfaces fit narrow screens at large text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    for (final path in [
      '/profile',
      '/profile/info',
      '/settings',
      '/profile/edit',
    ]) {
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await open(tester, path);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
      for (var scroll = 0; scroll < 4; scroll++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$path scroll $scroll');
      }
    }
  });

  testWidgets('Downloads card panda pose differs from empty-state panda', (
    tester,
  ) async {
    await open(tester, '/downloads');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel ==
                'Hyzen panda waving from the offline library card',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is HyzenRiveMascot &&
            widget.state == HyzenRiveState.downloading,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all app sections load real screens', (tester) async {
    for (final path in [
      '/home',
      '/study',
      '/search',
      '/pdf-studio',
      '/downloads',
      '/profile',
    ]) {
      await open(tester, path);
      expect(tester.takeException(), isNull, reason: path);
      expect(find.textContaining('Screen coming soon'), findsNothing);
    }
  });
  testWidgets('NAV-01/02 five equal destinations in the requested order', (
    tester,
  ) async {
    await open(tester, '/home');
    final dock = find.byKey(const ValueKey('main-dock'));
    expect(find.byType(NavigationBar), findsNothing);
    final buttons = find.descendant(of: dock, matching: find.byType(InkWell));
    expect(buttons, findsNWidgets(5));
    expect(DockDestination.values.map((d) => d.label).toList(), [
      'Home',
      'Study',
      'Office Workspace',
      'Shop',
      'Downloads',
    ]);
    double previous = -1;
    for (final destination in DockDestination.values) {
      final target = find.byKey(ValueKey('dock-${destination.name}'));
      final rect = tester.getRect(target);
      expect(rect.left, greaterThan(previous));
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
      previous = rect.left;
    }
    expect(tester.widget<Material>(dock).color, Colors.black);
  });

  testWidgets(
    'NAV-03/04/05 Study hub, independent Downloads and center workspace',
    (tester) async {
      await open(tester, '/home');
      for (final destination in [
        DockDestination.study,
        DockDestination.downloads,
        DockDestination.office,
      ]) {
        await tester.tap(find.byTooltip(destination.label));
        await tester.pumpAndSettle();
        expect(
          container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          destination.route,
        );
        for (final item in DockDestination.values) {
          expect(
            tester
                .widget<Semantics>(find.byKey(ValueKey('dock-${item.name}')))
                .properties
                .selected,
            item == destination,
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Study'));
      await tester.pumpAndSettle();
      expect(find.text('Notes'), findsWidgets);
      expect(find.text('MCQs'), findsWidgets);
      for (final path in [
        '/study/notes',
        '/study/special',
        '/study/mcqs',
        '/study/papers',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Semantics>(find.byKey(const ValueKey('dock-study')))
              .properties
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<Semantics>(find.byKey(const ValueKey('dock-downloads')))
              .properties
              .selected,
          isFalse,
        );
      }
    },
  );

  testWidgets(
    'NAV-06 Study child stack and Downloads filters survive tab switches',
    (tester) async {
      const child = '/study/notes/id-0/id-1/id-2/id-3/id-4';
      final record = DownloadRecord(
        key: 'retained',
        kind: LibraryKind.notes,
        title: 'Retained download',
        sourceUrl: 'https://example.org/retained.pdf',
        status: DownloadStatus.paused,
        progress: .4,
        sizeBytes: 400,
        totalBytes: 1000,
      );
      await tester.runAsync(
        () => JsonBox(Boxes.downloads).put(record.key, record.toMap()),
      );
      await open(tester, child);
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('dock-study')))
            .properties
            .selected,
        isTrue,
      );
      await tester.tap(find.byTooltip('Downloads'));
      await tester.pumpAndSettle();
      final controller = container.read(downloadsProvider.notifier);
      expect(container.read(downloadsProvider)['retained']?.progress, .4);
      await tester.enterText(find.byType(TextField).first, 'Retained');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Study'));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        child,
      );
      expect(find.text('Insulin Notes'), findsOneWidget);
      await tester.tap(find.byTooltip('Downloads'));
      await tester.pumpAndSettle();
      expect(
        identical(controller, container.read(downloadsProvider.notifier)),
        isTrue,
      );
      expect(container.read(downloadsProvider)['retained']?.progress, .4);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        'Retained',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'NAV-07 auxiliary routes retain access and account hides the dock',
    (tester) async {
      for (final path in [
        '/search',
        '/profile',
        '/profile/info',
        '/profile/edit',
        '/settings',
      ]) {
        await open(tester, path);
        expect(
          container
              .read(routerProvider)
              .routeInformationProvider
              .value
              .uri
              .path,
          path,
        );
        expect(
          find.byType(MainDock),
          path.startsWith('/profile') || path == '/settings'
              ? findsNothing
              : findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: path);
      }
    },
  );

  testWidgets(
    'NAV-08/09 narrow dock, large text, safe area and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DockDestination selected = DockDestination.home;
      for (final reduce in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 900),
                textScaler: TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24),
                disableAnimations: reduce,
              ),
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  bottomNavigationBar: MainDock(
                    path: selected.route,
                    onSelected: (value) => setState(() => selected = value),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final destination in [
          DockDestination.office,
          DockDestination.downloads,
        ]) {
          await tester.tap(find.byTooltip(destination.label));
          await tester.pump(const Duration(milliseconds: 10));
          expect(
            selected,
            destination,
            reason: 'Animation must not delay navigation',
          );
        }
        if (reduce) {
          for (final scale in tester.widgetList<AnimatedScale>(
            find.byType(AnimatedScale),
          )) {
            expect(scale.duration, Duration.zero);
            expect(scale.scale, 1);
          }
        }
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const ValueKey('main-dock'))).bottom,
          876,
        );
        for (final destination in DockDestination.values) {
          expect(
            tester
                .getSize(find.byKey(ValueKey('dock-${destination.name}')))
                .width,
            greaterThanOrEqualTo(48),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'NAV-10 signed-out Login and password recovery routes remain usable',
    (tester) async {
      final guest = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith((ref) => Stream.value(null)),
          contentProvider.overrideWith(
            (ref, key) => Stream.value(
              const ContentSnapshot(value: {}, fromCache: false),
            ),
          ),
        ],
      );
      addTearDown(guest.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: guest, child: const HyzenApp()),
      );
      await tester.pumpAndSettle();
      guest.read(routerProvider).go('/login');
      await tester.pumpAndSettle();
      expect(find.text('Welcome to PHARM D WITH HYZEN'), findsOneWidget);
      expect(find.byKey(const ValueKey('login-panda-hero')), findsOneWidget);
      expect(find.byType(MainDock), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'student@example.org',
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot your password?'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .initialValue,
        'student@example.org',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account surfaces follow persisted Light and Dark without changing layout',
    (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        container.read(themeModeProvider.notifier).set(mode);
        for (final path in ['/profile', '/profile/info', '/settings']) {
          await open(tester, path);
          final context = tester.element(find.byType(AccountPage));
          expect(
            Theme.of(context).brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
          final cards = find.descendant(
            of: find.byType(SettingsCard).first,
            matching: find.byType(Material),
          );
          expect(
            tester.widget<Material>(cards.first).color,
            mode == ThemeMode.dark
                ? (path == '/profile' || path == '/settings'
                      ? AccountStyle.raised
                      : AccountStyle.card)
                : Colors.white,
          );
          expect(prefs.getString('theme_mode'), mode.name);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  testWidgets('narrow phone layouts and large text remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final path in [
      '/home',
      '/study',
      '/search',
      '/downloads',
      '/profile',
    ]) {
      await open(tester, path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });
  testWidgets('every library level resolves through the router', (
    tester,
  ) async {
    await open(tester, '/study/notes/id-0/id-1/id-2/id-3/id-4');
    expect(find.text('Insulin Notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('blog, about, contact and safe missing viewer render', (
    tester,
  ) async {
    for (final path in [
      '/blog',
      '/blog/b1',
      '/about',
      '/contact',
      '/viewer',
      '/settings',
      '/shop',
      '/cart',
      '/orders',
    ]) {
      await open(tester, path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });
  testWidgets(
    'Android back returns to Home from a tab and pops one library level',
    (tester) async {
      await open(tester, '/study');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/home',
      );
      await open(tester, '/study/notes/id-0/id-1/id-2');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/study/notes/id-0/id-1',
      );
      await open(tester, '/home');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Keep studying'), findsOneWidget);
      await tester.tap(find.text('Keep studying'));
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/home',
      );
    },
  );
  testWidgets('Android back from Settings stays in the app and returns Home', (
    tester,
  ) async {
    await open(tester, '/settings');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/home',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Android back from Create PDF returns to the workspace', (
    tester,
  ) async {
    const camera = MethodChannel('com.hyzen.pharmd/camera_pages');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(camera, (_) async => <String>[]);
    addTearDown(() => messenger.setMockMethodCallHandler(camera, null));
    await open(tester, '/pdf-studio');
    container.read(routerProvider).push('/create-pdf');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/pdf-studio',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'external history id resolves without route extras or a signed-in account',
    (tester) async {
      final guest = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith((ref) => Stream.value(null)),
          contentProvider.overrideWith(
            (ref, key) => Stream.value(
              const ContentSnapshot(value: {}, fromCache: false),
            ),
          ),
        ],
      );
      addTearDown(guest.dispose);
      await tester.runAsync(
        () => guest
            .read(externalHistoryProvider.notifier)
            .add(
              ExternalDocument(
                'fixture-id',
                'External lecture.txt',
                '/tmp/external-lecture.txt',
                DateTime.now(),
              ),
            ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: guest, child: const HyzenApp()),
      );
      await tester.pumpAndSettle();
      guest.read(routerProvider).go('/imported-viewer?id=fixture-id');
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('External lecture.txt'), findsOneWidget);
      expect(find.text('This page could not be found'), findsNothing);
      expect(
        guest.read(routerProvider).routeInformationProvider.value.uri.path,
        '/imported-viewer',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reference Home hero and positioned profile fit a 360px phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, '/home');
    expect(find.byKey(const ValueKey('home-hero-art')), findsOneWidget);
    expect(find.text('Others'), findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('Profile & settings')).left,
      lessThan(40),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('splash uses the dedicated loading mascot state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(
      find.byWidgetPredicate(
        (w) => w is HyzenRiveMascot && w.state == HyzenRiveState.loading,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('onboarding mounts a semantic mascot state for every page', (
    tester,
  ) async {
    final tutorialContainer = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(tutorialContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: tutorialContainer,
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HyzenRiveMascot), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.byType(HyzenRiveMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('accessibility preferences persist and clamp text scaling', () async {
    final accessibility = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(accessibility.dispose);

    accessibility
        .read(doublePrefProvider('pref_text_scale').notifier)
        .set(1.2);
    accessibility
        .read(boolPrefProvider('pref_reduce_motion').notifier)
        .set(true);

    expect(accessibility.read(doublePrefProvider('pref_text_scale')), 1.2);
    expect(accessibility.read(boolPrefProvider('pref_reduce_motion')), isTrue);
    expect(prefs.getDouble('pref_text_scale'), 1.2);
    expect(prefs.getBool('pref_reduce_motion'), isTrue);

    accessibility
        .read(doublePrefProvider('pref_text_scale').notifier)
        .set(9);
    expect(accessibility.read(doublePrefProvider('pref_text_scale')), 1.35);
  });

  testWidgets(
    'Login remains usable at 320px with large text, both themes and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final guest = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          profileProvider.overrideWith((ref) => Stream.value(null)),
          contentProvider.overrideWith(
            (ref, key) => Stream.value(
              const ContentSnapshot(value: {}, fromCache: false),
            ),
          ),
        ],
      );
      addTearDown(guest.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: guest, child: const HyzenApp()),
      );
      await tester.pumpAndSettle();
      guest.read(routerProvider).go('/login');
      await tester.pumpAndSettle();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        guest.read(themeModeProvider.notifier).set(mode);
        await tester.pumpAndSettle();
        expect(find.text('Welcome back'), findsNothing);
        expect(find.byType(HyzenBrandIcon), findsOneWidget);
        await tester.ensureVisible(find.text('Log in'));
        await tester.tap(find.text('Log in'));
        await tester.pumpAndSettle();
        expect(find.text('Email is required'), findsOneWidget);
        expect(find.text('Password is required'), findsOneWidget);
        await tester.ensureVisible(find.byType(TextFormField).first);
        await tester.enterText(
          find.byType(TextFormField).first,
          'student@example.org',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Show password'));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.enterText(find.byType(TextFormField).first, '');
      }
    },
  );
  testWidgets(
    'Study and Downloads banners use approved panda artwork in both themes',
    (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        container.read(themeModeProvider.notifier).set(mode);
        for (final path in ['/study', '/downloads']) {
          await open(tester, path);
          final art = find.descendant(
            of: find.byType(HyzenBanner),
            matching: find.byType(Image),
          );
          ImageProvider asset = tester.widget<Image>(art.first).image;
          if (asset is ResizeImage) asset = asset.imageProvider;
          expect(
            (asset as AssetImage).assetName,
            startsWith('assets/mascot/mascot_'),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  test(
    'academic content switches when a student changes professional year',
    () async {
      final selectedYear = StateProvider<int>((ref) => 2);
      final academic = ProviderContainer(
        overrides: [
          profileProvider.overrideWith((ref) => Stream.value(null)),
          professionalYearProvider.overrideWith(
            (ref) => ref.watch(selectedYear),
          ),
          isAdminProvider.overrideWithValue(false),
          contentProvider.overrideWith(
            (ref, key) => Stream.value(
              ContentSnapshot(
                value: key == 'pw_lectures_tree'
                    ? [
                        {
                          'id': 'year1',
                          'label': '1st Professional',
                          'semesters': [],
                        },
                        {
                          'id': 'year2',
                          'label': '2nd Professional',
                          'semesters': [],
                        },
                      ]
                    : [
                        {
                          'id': 'year1',
                          'label': '1st Professional',
                          'semesters': [],
                        },
                        {
                          'id': 'year2',
                          'label': '2nd Professional',
                          'semesters': [],
                        },
                      ],
                fromCache: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(academic.dispose);
      final subscription = academic.listen(
        libraryProvider(LibraryKind.notes),
        (_, __) {},
      );
      addTearDown(subscription.close);
      await academic.read(parsedLibraryProvider(LibraryKind.notes).future);
      expect(
        academic
            .read(libraryProvider(LibraryKind.notes))
            .value!
            .data
            .years
            .single
            .id,
        'year2',
      );
      await academic.read(contentProvider('pw_lectures_tree').future);
      expect(academic.read(lecturesProvider).value!.data.single.id, 'year2');
      academic.read(selectedYear.notifier).state = 1;
      expect(
        academic
            .read(libraryProvider(LibraryKind.notes))
            .value!
            .data
            .years
            .single
            .id,
        'year1',
      );
    },
  );
  testWidgets(
    'completed student profile is retained without a repeat completion prompt',
    (tester) async {
      await open(tester, '/profile');
      expect(find.text('Ali Raza'), findsWidgets);
      expect(find.text('Complete your profile'), findsNothing);
      expect(find.textContaining('synced on this device'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('student cannot enter admin routes', (tester) async {
    await open(tester, '/admin/import');
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/home',
    );
  });
  testWidgets('small phone home layout supports larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HyzenApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin settings, import template and content editor render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final admin = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(StudentUser())),
        profileProvider.overrideWith((ref) => Stream.value(null)),
        isAdminProvider.overrideWithValue(true),
        adminValueProvider.overrideWith(
          (ref, key) => Stream.value(
            key == 'pw_credits'
                ? {'cards': [], 'layout': 'stack'}
                : key == 'pw_settings'
                ? {'shopComingSoon': false}
                : key == 'pw_lectures_tree'
                ? fixtureTree
                : key == 'pw_products' ||
                      key == 'pw_orders' ||
                      key == 'pw_messages' ||
                      key == 'pw_blogs' ||
                      key == 'pw_social' ||
                      key == 'pw_import_history'
                ? []
                : {},
          ),
        ),
        contentProvider.overrideWith(
          (ref, key) => Stream.value(
            ContentSnapshot(
              value: key == 'pw_settings' ? {'shopComingSoon': false} : [],
              fromCache: false,
            ),
          ),
        ),
        adminTreeProvider.overrideWith(
          (ref, kind) async => copyTree(fixtureTree, kind),
        ),
      ],
    );
    addTearDown(admin.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: admin, child: const HyzenApp()),
    );
    await tester.pumpAndSettle();
    for (final path in [
      '/admin',
      '/admin/stats',
      '/admin/manage/products',
      '/admin/manage/orders',
      '/admin/manage/messages',
      '/admin/manage/credits',
      '/admin/manage/social',
      '/admin/manage/blogs',
      '/admin/manage/lectures',
      '/admin/manage/settings',
      '/admin/manage/announcement',
      '/admin/manage/notice',
      '/admin/manage/catalog',
      '/admin/manage/delivery',
      '/admin/manage/data',
      '/admin/manage/history',
      '/admin/manage/theme',
      '/admin/manage/connection',
      '/admin/sections',
      '/admin/import',
      '/admin/content/notes',
    ]) {
      admin.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
      if (path == '/admin' && const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          admin.read(themeModeProvider.notifier).set(mode);
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(HyzenApp),
            matchesGoldenFile('../qa/${mode.name}_admin.png'),
          );
        }
        admin.read(themeModeProvider.notifier).set(ThemeMode.system);
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('2nd Professional'), findsOneWidget);
  });
  if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
    testWidgets('representative screens visual QA', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.read(themeModeProvider.notifier).set(mode);
        for (final path in [
          '/home',
          '/study',
          '/pdf-studio',
          '/study/notes/id-0/id-1/id-2/id-3/id-4',
          '/downloads',
          '/profile',
          '/contact',
          '/settings',
          '/about',
        ]) {
          await open(tester, path);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 120)),
          );
          await tester.pump();
          await expectLater(
            find.byType(HyzenApp),
            matchesGoldenFile(
              '../qa/${mode.name}${path.replaceAll('/', '_')}.png',
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
}

import 'package:hyzen_pharmd/features/study_progress/study_calendar.dart';
import 'package:hyzen_pharmd/features/study_progress/reward_controller.dart';
import 'package:hyzen_pharmd/core/widgets/workspace_icons.dart';
import 'package:hyzen_pharmd/core/widgets/display_preferences.dart';
import 'package:hyzen_pharmd/core/widgets/profile_avatar.dart';
import 'package:hyzen_pharmd/core/widgets/polish_ui.dart';
import 'package:hyzen_pharmd/features/search/presentation/search_screen.dart';
import 'package:hyzen_pharmd/core/widgets/ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:hyzen_pharmd/features/academics/presentation/library_screens.dart';
import 'package:hyzen_pharmd/features/downloads/presentation/downloads_screen.dart';
import 'package:hyzen_pharmd/features/pdf_studio/presentation/scan_pdf_screen.dart';
import 'package:hyzen_pharmd/features/study_progress/study_progress_screen.dart';
import 'dart:io';
import 'package:hyzen_pharmd/features/notifications/notifications_screen.dart';
import 'package:hyzen_pharmd/features/study_progress/study_forms.dart';
import 'package:hyzen_pharmd/features/study_progress/study_tracker.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_screen.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_background.dart';
import 'package:hyzen_pharmd/features/home/data/recent_controller.dart';
import 'package:hyzen_pharmd/features/viewer/offline_pdf.dart';
import 'package:hyzen_pharmd/features/academics/presentation/discovery_widgets.dart';
import 'package:hyzen_pharmd/core/theme/tokens.dart';
import 'package:hyzen_pharmd/core/theme/app_theme.dart';
import 'package:hyzen_pharmd/core/widgets/surfaces.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hyzen_pharmd/features/home/presentation/home_dashboard_top.dart';
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
import 'package:hyzen_pharmd/core/widgets/hyzen_art.dart';
import 'package:hyzen_pharmd/features/auth/presentation/splash_welcome_screens.dart';

class StudentUser extends Fake implements User {
  StudentUser({this.photoURL});

  @override
  String get uid => 'student-test';
  @override
  String? get displayName => 'Test Student';
  @override
  String? get email => 'student@example.org';
  @override
  final String? photoURL;
}

void main() {
  late Directory temp;
  late SharedPreferences prefs;
  late ProviderContainer container;
  late List<Map<String, dynamic>> fixtureTree;
  String? accountPhoto;
  var qaClock = DateTime(2026, 1, 1, 18);
  setUpAll(() async {
    final fonts = FontLoader('Outfit');
    for (final weight in [400, 500, 600, 700]) {
      fonts.addFont(rootBundle.load('assets/fonts/Outfit-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    accountPhoto = null;
    qaClock = DateTime(2026, 1, 1, 18);
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
    await prefs.setBool('pref_ambient_motion', false);
    container = ProviderContainer(
      overrides: [
        homeClockProvider.overrideWithValue(() => qaClock),
        sharedPrefsProvider.overrideWithValue(prefs),
        // Widget navigation verifies planner state; OS alarm delivery is a
        // separate native check, outside fake-async widget scheduling.
        calendarProvider.overrideWith(
          (ref) =>
              CalendarController(prefs, 'ui-calendar', null, (_, __) async {}),
        ),
        authStateProvider.overrideWith(
          (ref) => Stream.value(StudentUser(photoURL: accountPhoto)),
        ),
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
      UncontrolledProviderScope(
        container: container,
        child: const RepaintBoundary(
          key: ValueKey('qa-app'),
          child: HyzenApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'display sizes change, persist on rebuild, and reset to Android defaults',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, '/settings');
      final text = find.byKey(const ValueKey('ui_text_scale'));
      final elements = find.byKey(const ValueKey('ui_element_scale'));
      await tester.scrollUntilVisible(
        text,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(text);
      await tester.pumpAndSettle();

      final reset = find.text('Reset sizes');
      expect(tester.widget<Slider>(text).value, 1);
      expect(tester.widget<Slider>(elements).value, 1);
      expect(
        MediaQuery.textScalerOf(tester.element(text)).scale(20),
        closeTo(32, .01),
      );
      expect(UiDensity.of(tester.element(elements)), 1);

      await tester.drag(text, const Offset(500, 0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(elements);
      await tester.pumpAndSettle();
      await tester.drag(elements, const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(prefs.getDouble('ui_text_scale'), 1.25);
      expect(prefs.getDouble('ui_element_scale'), 1.15);
      expect(
        MediaQuery.textScalerOf(tester.element(elements)).scale(20),
        closeTo(40, .01),
      );
      expect(UiDensity.of(tester.element(elements)), 1.15);

      final restarted = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(restarted.dispose);
      expect(restarted.read(displayScaleProvider('ui_text_scale')), 1.25);
      expect(restarted.read(displayScaleProvider('ui_element_scale')), 1.15);

      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(prefs.getDouble('ui_text_scale'), 1);
      expect(prefs.getDouble('ui_element_scale'), 1);
      expect(
        MediaQuery.textScalerOf(tester.element(elements)).scale(20),
        closeTo(32, .01),
      );
      expect(UiDensity.of(tester.element(elements)), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home plan cards keep words intact at 320 and 360dp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [320.0, 360.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final scale in [1.0, 1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        container
            .read(displayScaleProvider('ui_text_scale').notifier)
            .set(scale == 1 ? 1 : 1.25);
        container
            .read(displayScaleProvider('ui_element_scale').notifier)
            .set(1.15);
        await open(tester, '/home');
        final title = find.text('Study library');
        await tester.scrollUntilVisible(
          title,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        for (final label in [
          'Study library',
          'Notes, MCQs & past papers',
          'Office workspace',
        ]) {
          final finder = find.text(label);
          await tester.ensureVisible(finder);
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          for (final match in RegExp(r'\S+').allMatches(label)) {
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: match.start, extentOffset: match.end),
            );
            expect(
              boxes.length,
              1,
              reason: '${match.group(0)} at ${width}dp / $scale×',
            );
          }
        }
        if (const bool.fromEnvironment('HYZEN_CAPTURE_QA') &&
            width == 360 &&
            scale == 1.3) {
          await Scrollable.ensureVisible(tester.element(title), alignment: .25);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(HyzenApp),
            matchesGoldenFile('../qa/reference/after/home-note8-large.png'),
          );
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'core screens fit narrow phones with maximum app and Android sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      container.read(displayScaleProvider('ui_text_scale').notifier).set(1.25);
      container
          .read(displayScaleProvider('ui_element_scale').notifier)
          .set(1.15);

      for (final width in [320.0, 360.0]) {
        tester.view.physicalSize = Size(width, 844);
        for (final path in [
          '/settings',
          '/study',
          '/pdf-studio',
          '/downloads',
          '/study-progress',
          '/notifications',
          '/search',
        ]) {
          await open(tester, path);
          expect(tester.takeException(), isNull, reason: '$path at ${width}dp');
          final scrollable = find.byType(Scrollable).first;
          for (var i = 0; i < 3; i++) {
            await tester.drag(scrollable, const Offset(0, -580));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$path at ${width}dp after scroll',
            );
          }
        }
      }
    },
  );

  testWidgets(
    'Home, shared, and Office headers use the signed-in account photo',
    (tester) async {
      accountPhoto = 'https://example.org/avatar.png';
      for (final route in ['/home', '/study', '/downloads', '/pdf-studio']) {
        await open(tester, route);
        final avatars = tester.widgetList<ProfileAvatar>(
          find.byType(ProfileAvatar),
        );
        expect(
          avatars.map((avatar) => avatar.photoUrl),
          contains(accountPhoto),
          reason: route,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('push inbox deduplicates receipt and preserves read status', (
    tester,
  ) async {
    await open(tester, '/home');
    final inbox = container.read(notificationsProvider.notifier);
    const message = {
      'id': 'push_same-provider-id',
      'title': 'New material',
      'body': 'Notes ready',
      'url': '/study',
    };
    inbox.receivePush(message);
    inbox.receivePush(message);
    expect(
      container
          .read(notificationsProvider)
          .where((m) => m['id'] == message['id'])
          .length,
      1,
    );
    inbox.receivePush({...message, 'opened': true});
    inbox.receivePush(message);
    expect(
      container
          .read(notificationsProvider)
          .singleWhere((m) => m['id'] == message['id'])['read'],
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'date ribbon keeps two-digit dates on one line at 320dp and 200% text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 288,
                child: StudyWeekRibbon(
                  now: DateTime(2026, 11, 17),
                  days: const {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var day = 16; day <= 22; day++) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('$day'),
        );
        expect(
          paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 2),
              )
              .map((box) => box.top)
              .toSet()
              .length,
          1,
          reason: '$day must remain a single readable date',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  test('HOME-03 time greeting boundaries', () {
    expect(homeGreeting(DateTime(2026, 1, 1, 6)), 'Good morning');
    expect(homeGreeting(DateTime(2026, 1, 1, 12)), 'Good afternoon');
    expect(homeGreeting(DateTime(2026, 1, 1, 17)), 'Good evening');
  });
  testWidgets(
    'HOME-01 reference artwork, real date and personalized light-only header',
    (tester) async {
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        container.read(themeModeProvider.notifier).set(mode);
        await open(tester, '/home');
        expect(find.byType(HomeAtmosphere), findsOneWidget);
        final greeting = tester.widget<Text>(
          find.byKey(const ValueKey('home-greeting')),
        );
        expect(greeting.data, 'Hello, Ali');
        expect(find.text('Today 1 Jan'), findsNothing);
        expect(greeting.style!.color, isNot(HColors.mint));
        expect(find.text('Hello, Ali'), findsOneWidget);
        final accountAction = tester.getSize(
          find.byTooltip('Profile & settings'),
        );
        expect(accountAction.width, greaterThanOrEqualTo(48));
        expect(accountAction.height, greaterThanOrEqualTo(48));
        expect(find.byKey(const ValueKey('home-hero-art')), findsOneWidget);
        expect(find.text('More from Hyzen'), findsNothing);
        expect(find.text('About Hyzen'), findsNothing);
        expect(find.text('Contact us'), findsNothing);
        final search = find.byTooltip('Search academic resources');
        expect(Theme.of(tester.element(search)).brightness, Brightness.light);
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
    await tester.scrollUntilVisible(
      find.text('Test academic announcement'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
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
      await tester.scrollUntilVisible(
        clear,
        250,
        scrollable: find.byType(Scrollable).first,
      );
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
      'Search academic resources': '/search',
      'Study Library': '/study',
      'Office Workspace': '/pdf-studio',
      'Downloads': '/downloads',
      'Shop': '/shop',
    }.entries) {
      await open(tester, '/home');
      final Finder target;
      if (entry.key == 'Search academic resources') {
        target = find.byTooltip(entry.key);
      } else if (entry.key == 'Study Library' ||
          entry.key == 'Office Workspace') {
        target = find.byWidgetPredicate(
          (w) => w is HCard && w.semanticLabel == entry.key,
        );
      } else {
        target = find.byKey(ValueKey('dock-${entry.key.toLowerCase()}'));
      }
      if (entry.key != 'Downloads' && entry.key != 'Shop') {
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      }
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
      await tester.scrollUntilVisible(
        find.text('1 Saved'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 Saved'), findsOneWidget);
      expect(find.text('1 New'), findsOneWidget);
      expect(
        find.text('1 Downloading'),
        findsNothing,
        reason: 'Interrupted transfers restore as paused',
      );
      await tester.scrollUntilVisible(
        find.text('Actual recent notes'),
        200,
        scrollable: find.byType(Scrollable).first,
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
      await tester.scrollUntilVisible(
        find.byType(SubjectDiscovery),
        400,
        scrollable: find.byType(Scrollable).first,
      );
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
      final announcements = find.byWidgetPredicate(
        (widget) =>
            widget is AccountToggle && widget.label == 'Show announcements',
      );
      await tester.scrollUntilVisible(
        announcements,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(announcements);
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

  testWidgets('Downloads shows one pastel panda card and saved-file count', (
    tester,
  ) async {
    await open(tester, '/downloads');
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.semanticLabel == 'Hyzen panda with an offline download tablet',
      ),
      findsOneWidget,
    );
    expect(find.byType(HyzenRiveMascot), findsNothing);
    expect(find.text('0 saved files · 0 B'), findsOneWidget);
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
  testWidgets(
    'NAV-01/02 compact pill dock keeps five accessible destinations',
    (tester) async {
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
      final surface = find.descendant(
        of: dock,
        matching: find.byType(Material),
      );
      expect(
        tester.widget<Material>(surface.first).color,
        const Color(0xFFF0F0F2),
      );
    },
  );

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

  testWidgets('search starts empty after re-entry and a new session', (
    tester,
  ) async {
    await open(tester, '/search');
    await tester.enterText(find.byType(TextField).first, 'Insulin');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Insulin Notes'), findsWidgets);
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/search');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    await tester.enterText(find.byType(TextField).first, 'old query');
    container.read(sessionRevisionProvider.notifier).state++;
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  test('text size starts at 13 and restores the chosen numeric size', () async {
    expect(container.read(textSizeProvider), 13);
    await container.read(textSizeProvider.notifier).set(16);
    expect(prefs.getInt('app_text_size'), 16);
    container.invalidate(textSizeProvider);
    expect(container.read(textSizeProvider), 16);
  });

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
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
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
      expect(find.byType(TextFormField), findsNothing);
      await tester.ensureVisible(find.text('Already a user? Log in'));
      await tester.tap(find.text('Already a user? Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
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
    'account remains light while preserving legacy theme preferences',
    (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        container.read(themeModeProvider.notifier).set(mode);
        for (final path in ['/profile', '/profile/info', '/settings']) {
          await open(tester, path);
          final context = tester.element(find.byType(AccountPage));
          expect(Theme.of(context).brightness, Brightness.light);
          final cards = find.descendant(
            of: find.byType(SettingsCard).first,
            matching: find.byType(Material),
          );
          expect(tester.widget<Material>(cards.first).color, HColors.surface);
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
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // Long Study titles intentionally marquee. Freeze motion for layout QA.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester, '/home');
    await tester.runAsync(
      () => container.read(parsedLibraryProvider(LibraryKind.notes).future),
    );
    for (final path in [
      '/home',
      '/study',
      '/study/notes',
      '/pdf-studio',
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
  testWidgets('Home quick actions open notes camera scanner and downloads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const camera = MethodChannel('com.hyzen.pharmd/camera_pages');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      camera,
      (_) async => <String>[],
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        camera,
        null,
      ),
    );
    for (final action in [
      ('notes', '/study/notes', LibraryLevelScreen),
      ('scan', '/create-pdf?source=camera', ScanPdfScreen),
      ('downloads', '/downloads', DownloadsScreen),
    ]) {
      await open(tester, '/home');
      final button = find.byKey(ValueKey('home-action-${action.$1}'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final screen = find.byType(action.$3);
      expect(screen, findsOneWidget);
      expect(
        GoRouterState.of(tester.element(screen)).uri.toString(),
        action.$2,
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'calendar and streak adapt to phone/tablet widths and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final width in [320.0, 360.0, 390.0, 430.0, 800.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 844);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (final route in [
            '/study-calendar',
            '/study-streak',
            '/study-progress',
          ]) {
            await open(tester, route);
            expect(
              tester.takeException(),
              isNull,
              reason: '$route at $width / $scale',
            );
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -580),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$route after scroll at $width / $scale',
            );
          }
        }
      }
    },
  );
  testWidgets('calendar opens selected Home date and colors its event pill', (
    tester,
  ) async {
    qaClock = DateTime(2026, 11, 18);
    await open(tester, '/home');
    await tester.ensureVisible(find.byType(StudyWeekRibbon));
    await tester.tap(
      find.descendant(
        of: find.byType(StudyWeekRibbon),
        matching: find.text('18'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StudyCalendarScreen), findsOneWidget);
    expect(
      GoRouterState.of(
        tester.element(find.byType(StudyCalendarScreen)),
      ).uri.queryParameters['date'],
      '2026-11-18',
    );
    await container
        .read(calendarProvider)
        .put(
          PlannerEvent(
            id: 'exam-fixture',
            title: 'Pharmacology paper',
            at: DateTime(2026, 11, 18, 9),
            color: 0xffd46a61,
            kind: 'Exam',
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('Pharmacology paper'), findsOneWidget);
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    final boxes = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(StudyWeekRibbon),
        matching: find.byType(Container),
      ),
    );
    expect(
      boxes.any(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == const Color(0xffd46a61),
      ),
      isTrue,
    );
    expect(container.read(studyTrackerProvider).running, isFalse);
  });
  testWidgets('points bubble hides without changing confirmed wallet', (
    tester,
  ) async {
    await open(tester, '/home');
    container.read(rewardProvider).apply({
      'today': '2026-11-18',
      'points': 950,
      'streak': 7,
      'bestStreak': 7,
      'claimedDays': ['2026-11-18'],
      'claimedMilestones': [5],
    });
    await tester.pumpAndSettle();
    expect(find.text('My Points 950'), findsOneWidget);
    await tester.tap(find.text('My Points 950'));
    await tester.pumpAndSettle();
    expect(find.text('My Points 950'), findsNothing);
    expect(container.read(rewardProvider).points, 950);
  });
  testWidgets(
    'Daily Challenge opens progress without starting a manual session',
    (tester) async {
      await open(tester, '/home');
      await tester.tap(find.byKey(const ValueKey('home-focus-card')));
      await tester.pumpAndSettle();
      expect(container.read(studyTrackerProvider).running, isFalse);
      expect(
        GoRouterState.of(
          tester.element(find.byType(StudyProgressScreen)),
        ).uri.path,
        '/study-progress',
      );
      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/home',
      );
      expect(container.read(studyTrackerProvider).running, isFalse);
      container.read(studyTrackerProvider).pause();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Home inline search filters and carries query to full search', (
    tester,
  ) async {
    await open(tester, '/home');
    final search = find.byKey(const ValueKey('home-search-input'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Insulin');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    for (final scope in ['notes', 'books', 'lectures', 'downloads']) {
      expect(find.byKey(ValueKey('search-scope-$scope')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('search-scope-notes')));
    await tester.pumpAndSettle();
    expect(find.text('Insulin Notes'), findsOneWidget);
    await tester.ensureVisible(find.text('View all results'));
    await tester.tap(find.text('View all results'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(HSearchField),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller?.text, 'Insulin');
    expect(find.text('Insulin Notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard search submission retains the selected category', (
    tester,
  ) async {
    await open(tester, '/home');
    final input = find.byKey(const ValueKey('home-search-input'));
    await Scrollable.ensureVisible(tester.element(input), alignment: .35);
    await tester.pumpAndSettle();
    await tester.enterText(input, 'Pharmacology');
    await tester.pump(const Duration(milliseconds: 250));
    final books = find.byKey(const ValueKey('search-scope-books'));
    await Scrollable.ensureVisible(tester.element(books), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(books);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(input), alignment: .35);
    await tester.pumpAndSettle();
    await tester.tap(input);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SearchScreen>(find.byType(SearchScreen)).initialScope.name,
      'books',
    );
    expect(
      tester.widget<SearchScreen>(find.byType(SearchScreen)).initialQuery,
      'Pharmacology',
    );
  });
  testWidgets('hold previews preserve Home until explicitly opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final name in ['Study Library', 'Office Workspace']) {
      await open(tester, '/home');
      final card = find.byWidgetPredicate(
        (w) => w is HCard && w.semanticLabel == name,
      );
      await tester.ensureVisible(card);
      await tester.longPress(card);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card-hold-preview')), findsOneWidget);
      expect(find.text(name), findsOneWidget);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/home',
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
        await expectLater(
          find.byType(HyzenApp),
          matchesGoldenFile(
            '../qa/reference/after/hold-${name.startsWith('Study') ? 'study' : 'office'}.png',
          ),
        );
      }
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card-hold-preview')), findsNothing);
    }
  });
  testWidgets('display sliders retain Android text scaling', (tester) async {
    await container.read(textSizeProvider.notifier).set(6);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, '/home');
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(HomeScreen)),
      ).scale(14),
      21,
    );
    await open(tester, '/settings');
    expect(find.byKey(const ValueKey('ui_text_scale')), findsOneWidget);
    expect(find.byKey(const ValueKey('ui_element_scale')), findsOneWidget);
  });
  testWidgets('notification unread filter and read-all update real inbox', (
    tester,
  ) async {
    await open(tester, '/notifications');
    final inbox = container.read(notificationsProvider.notifier);
    inbox.readAll();
    inbox.receivePush({
      'id': 'test-polish-new',
      'title': 'New lecture',
      'body': 'A new class is available',
      'url': '',
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread · 1'));
    await tester.pumpAndSettle();
    expect(find.text('New lecture'), findsOneWidget);
    await tester.tap(find.text('Read all'));
    await tester.pumpAndSettle();
    expect(find.text('New lecture'), findsNothing);
    expect(find.text('You’re up to date'), findsOneWidget);
  });
  testWidgets(
    'hero motion settles and reduced motion uses a static transform',
    (tester) async {
      for (final reduced in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: const HSoftArt(child: Text('Art')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        final translate = tester
            .widgetList<Transform>(find.byType(Transform))
            .first;
        expect(translate.transform.getTranslation().y.abs(), lessThan(.001));
      }
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
    expect(find.text('Your plan'), findsOneWidget);
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
  testWidgets('panda onboarding retains later mascot pages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const WelcomeScreen()),
    );
    expect(
      find.text('Thrilled to join\nyour learning\njourney!'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is WorkspaceIcon && widget.glyph == WorkspaceGlyph.panda,
      ),
      findsOneWidget,
    );
    final slider = find.byKey(const ValueKey('onboarding-slide'));
    final bounds = tester.getRect(slider);
    await tester.dragFrom(
      bounds.centerLeft + const Offset(27, 0),
      Offset(bounds.width - 48, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HyzenRiveMascot), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      expect(find.byType(TextFormField), findsNothing);
      await tester.ensureVisible(find.text('Already a user? Log in'));
      await tester.tap(find.text('Already a user? Log in'));
      await tester.pumpAndSettle();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        guest.read(themeModeProvider.notifier).set(mode);
        await tester.pumpAndSettle();
        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.byKey(const ValueKey('login-panda-hero')), findsOneWidget);
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
    'Study, Notes, Office and Downloads share compact hierarchy in both themes',
    (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        container.read(themeModeProvider.notifier).set(mode);
        for (final path in [
          '/study',
          '/study/notes',
          '/pdf-studio',
          '/downloads',
        ]) {
          await open(tester, path);
          expect(
            find.byType(HyzenBanner),
            (path == '/study/notes' || path == '/pdf-studio')
                ? findsNothing
                : findsOneWidget,
          );
          if (path == '/pdf-studio') {
            expect(find.text('Gallery'), findsOneWidget);
            expect(find.text('Your workspace'), findsOneWidget);
          }
          expect(find.byType(HomeAtmosphere), findsWidgets);
          expect(find.byTooltip('Profile & settings'), findsOneWidget);
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
      UncontrolledProviderScope(
        container: container,
        child: const RepaintBoundary(
          key: ValueKey('qa-app'),
          child: HyzenApp(),
        ),
      ),
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
            matchesGoldenFile('../qa/reference/after/${mode.name}_admin.png'),
          );
        }
        admin.read(themeModeProvider.notifier).set(ThemeMode.system);
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('2nd Professional'), findsOneWidget);
    tester.view.physicalSize = const Size(320, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    admin.read(routerProvider).go('/admin/import');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Admin import at 320dp / 200%',
    );
  });
  if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
    testWidgets('onboarding reference visual QA', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      for (final route in ['/welcome', '/login', '/register/personal']) {
        guest.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(HyzenApp),
          matchesGoldenFile(
            '../qa/reference/after/light${route.replaceAll('/', '_')}.png',
          ),
        );
        if (route == '/login') {
          final login = find.text('Already a user? Log in');
          await tester.ensureVisible(login);
          await tester.tap(login);
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(HyzenApp),
            matchesGoldenFile('../qa/reference/after/light_login_form.png'),
          );
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
  if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
    testWidgets('representative screens visual QA', (tester) async {
      qaClock = DateTime(2026, 11, 18);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final mode in [ThemeMode.light]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.read(themeModeProvider.notifier).set(mode);
        for (final path in [
          '/home',
          '/study',
          '/pdf-studio',
          '/study-goals',
          '/study-progress',
          '/study-streak',
          '/study-calendar',
          '/study/notes/id-0/id-1/id-2/id-3/id-4',
          '/downloads',
          '/profile',
          '/contact',
          '/settings',
          '/about',
          '/notifications',
        ]) {
          await open(tester, path);
          if (path == '/notifications') {
            final inbox = container.read(notificationsProvider.notifier);
            inbox.receivePush({
              'id': 'preview-material',
              'title': 'New pharmacology notes',
              'body':
                  'Your next revision session is ready. Explore the latest academic resources.',
              'url': '/study/notes',
            });
            inbox.addLocalReminder(
              'A little focus goes a long way',
              'Take 25 minutes for your daily study goal.',
              'preview-goal',
            );
          }
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
              '../qa/reference/after/${mode.name}${path.replaceAll('/', '_')}.png',
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  }
  testWidgets('reference responsive matrix', (tester) async {
    final errorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      errorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = errorHandler);
    tester.view.devicePixelRatio = 1;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [320.0, 360.0, 390.0, 430.0, 768.0, 844.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, width == 844 ? 390 : 844);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          container.read(themeModeProvider.notifier).set(mode);
          for (final path in [
            '/home',
            '/study-goals',
            '/study-progress',
            '/study-streak',
            '/campus-rank',
            '/study',
            '/study/notes',
            '/pdf-studio',
            '/downloads',
            '/profile',
            '/settings',
            '/shop',
            '/search',
            '/notifications',
          ]) {
            await open(tester, path);
            final scrollable = tester.state<ScrollableState>(
              find.byType(Scrollable).first,
            );
            scrollable.position.jumpTo(scrollable.position.minScrollExtent);
            await tester.pumpAndSettle();
            if (path == '/home') {
              final button = tester.getRect(
                find.byKey(const ValueKey('home-focus-card')),
              );
              final documentBottom = button.bottom + scrollable.position.pixels;
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('home-professional-badge')),
                250,
                scrollable: find.byType(Scrollable).first,
              );
              final badge = tester.getRect(
                find.byKey(const ValueKey('home-professional-badge')),
              );
              final documentTop = badge.top + scrollable.position.pixels;
              expect(
                documentBottom,
                lessThan(documentTop),
                reason: 'Home actions must not overlap at $width / $scale',
              );
              scrollable.position.jumpTo(scrollable.position.minScrollExtent);
              await tester.pumpAndSettle();
            }
            if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
              await tester.pumpAndSettle();
              await expectLater(
                find.byKey(const ValueKey('qa-app')),
                matchesGoldenFile(
                  '../qa/reference/matrix/${path.substring(1)}-${mode.name}-${width.toInt()}-${scale.toInt()}.png',
                ),
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$path at $width text $scale ${mode.name}',
            );
            for (var scroll = 0; scroll < 10; scroll++) {
              await tester.drag(
                find.byType(Scrollable).first,
                const Offset(0, -600),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    '$path scroll $scroll at $width text $scale ${mode.name}',
              );
            }
          }
        }
      }
    }
    if (const bool.fromEnvironment('HYZEN_CAPTURE_QA')) {
      tester.view.physicalSize = const Size(360, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        container.read(themeModeProvider.notifier).set(mode);
        for (final reminder in [false, true]) {
          await open(tester, '/study-goals');
          final context = tester.element(find.byType(Scaffold).last);
          showStudyForm(
            context,
            container.read(studyTrackerProvider),
            reminder: reminder,
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(const ValueKey('qa-app')),
            matchesGoldenFile(
              '../qa/reference/matrix/form-${reminder ? 'reminder' : 'task'}-${mode.name}.png',
            ),
          );
          Navigator.pop(tester.element(find.byType(TextFormField).first));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDisableShadows = true;
  });
}

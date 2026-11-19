import 'features/study_progress/campus_rank_screen.dart';
// Browser-only review entrypoint. Renders the real app/routes with clearly
// labelled sample data; never used by lib/main.dart or Android builds.
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/storage/local_store.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/student_profile.dart';
import 'features/content/data/content_source.dart';
import 'features/admin/data/admin_repository.dart';
import 'features/admin/domain/import_csv.dart';
import 'features/academics/domain/models.dart';
import 'features/downloads/data/downloads_controller.dart';
import 'features/downloads/domain/download_record.dart';
import 'features/home/data/recent_controller.dart';
import 'features/pdf_studio/data/pdf_studio_repository.dart';
import 'features/pdf_studio/data/studio_file_item.dart';

const reviewProfile = StudentProfile(
  uid: 'ui-review-student',
  fullName: 'Muhammad Haris',
  mobile: '+923001234567',
  gender: 'male',
  city: 'Pattoki',
  professionalYear: 2,
  institutionName: 'Quaid-e-Azam College of Pharmacy',
  affiliationStatus: AffiliationStatus.nonAffiliated,
  email: 'student@example.com',
  rollNumber: 'DP-2420',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await Boxes.init();
  // Review-only URL overrides use the same persisted theme preference as the app.
  final reviewTheme = Uri.base.queryParameters['theme'];
  if (reviewTheme == 'light' || reviewTheme == 'dark') {
    await prefs.setString('theme_mode', reviewTheme!);
  }
  final requestedPath = Uri.base.fragment.isNotEmpty
      ? Uri.base.fragment
      : const String.fromEnvironment(
          'HYZEN_REVIEW_ROUTE',
          defaultValue: '/home',
        );
  final initialPath =
      const [
        '/welcome',
        '/login',
        '/forgot-password',
        '/register/personal',
        '/register/academic',
        '/register/credentials',
        '/lectures',
        '/notifications',
        '/cart',
        '/orders',
        '/about',
        '/contact',
        '/admin/stats',
        '/admin/sections',
        '/admin/import',
        '/admin/manage/data',
        '/admin/manage/history',
        '/admin/manage/rank-verification',
        '/admin/content/notes',
        '/admin/manage/settings',
        '/profile',
        '/profile/info',
        '/profile/edit',
        '/settings',
        '/home',
        '/study',
        '/study/notes',
        '/study/special',
        '/study/mcqs',
        '/study/papers',
        '/pdf-studio',
        '/shop',
        '/downloads',
        '/search',
        '/study-goals',
        '/study-streak',
        '/study-calendar',
        '/study-progress',
        '/campus-rank',
        '/admin',
      ].contains(requestedPath)
      ? requestedPath
      : '/home';
  // Auth previews are signed out only in this isolated sample-data entrypoint.
  final guestPreview =
      const ['/welcome', '/login', '/forgot-password'].contains(initialPath) ||
      initialPath.startsWith('/register/');
  final emptyHome = Uri.base.queryParameters['scenario'] == 'empty';
  final tree = <Map<String, dynamic>>[];
  var id = 0;
  if (!emptyHome) {
    mergeRows(
      tree,
      validateImport(
        'kind,professional_year,semester,subject,section,topic,title,url,published\n'
            'notes,2nd Professional,Semester 1,Pharmaceutical Chemistry and Medicinal Compounds 2A,Study Notes,Revision,Pharmaceutical Chemistry comprehensive examination revision notes,https://example.org/review-notes.pdf,true\n'
            'notes,2nd Professional,Semester 1,Physical Pharmacy,Study Notes,Revision,Physical Pharmacy,https://example.org/review-physical.pdf,true\n'
            'notes,2nd Professional,Semester 1,Functional English,Study Notes,Revision,Functional English,https://example.org/review-english.pdf,true\n'
            'notes,2nd Professional,Semester 1,Pharmacology,Study Notes,Revision,Pharmacology,https://example.org/review-pharmacology.pdf,true',
        'review.csv',
      ).rows,
      () => 'review-${id++}',
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        // Isolated fixture app only; production authorization is unchanged.
        isAdminProvider.overrideWithValue(initialPath.startsWith('/admin')),
        adminRepositoryProvider.overrideWithValue(_ReviewAdmin(tree)),
        campusBoardProvider.overrideWith(
          (ref, period) => _ReviewCampus(
            prefs,
            period,
            Uri.base.queryParameters['scenario'] == 'rank-setup',
          ),
        ),
        downloadsProvider.overrideWith(() => _ReviewDownloads(emptyHome)),
        recentProvider.overrideWith(() => _ReviewRecent(emptyHome)),
        pdfStudioHistoryProvider.overrideWith(() => _ReviewOffice(emptyHome)),
        authStateProvider.overrideWith(
          (ref) => Stream<User?>.value(guestPreview ? null : _ReviewUser()),
        ),
        authRepositoryProvider.overrideWithValue(_ReviewAuth()),
        profileProvider.overrideWith((ref) {
          if (guestPreview) return Stream<StudentProfile?>.value(null);
          final cached = ref
              .read(pendingProfileStoreProvider)
              .cached(reviewProfile.uid);
          return Stream.value(
            cached == null
                ? reviewProfile
                : StudentProfile.fromMap(reviewProfile.uid, cached),
          );
        }),
        contentProvider.overrideWith(
          (ref, key) => Stream.value(
            ContentSnapshot(
              value: key == 'pw_settings'
                  ? <String, dynamic>{
                      'lecturesEnabled': true,
                      if (Uri.base.queryParameters['scenario'] == 'notice')
                        'fullScreenNotice': {
                          'id': 'review-welcome',
                          'enabled': true,
                          'repeat': 'session',
                          'eyebrow': 'A little focus, every day',
                          'title': 'Welcome to your study space',
                          'body':
                              'Your notes, lectures and study progress, together in one place. Make yourself at home.',
                          'dismissText': 'Let’s get started',
                        },
                    }
                  : key == 'pw_lectures_tree'
                  ? [
                      {
                        'id': 'review-year',
                        'label': '2nd Professional',
                        'semesters': [
                          {
                            'id': 'review-semester',
                            'label': 'Semester 1',
                            'subjects': [
                              {
                                'id': 'review-subject',
                                'label': 'Pharmacy learning room',
                                'topics': [
                                  {
                                    'id': 'review-lecture',
                                    'title': 'Lecture player demonstration',
                                    'youtubeUrl':
                                        'https://www.youtube.com/watch?v=M7lc1UVf-VE',
                                    'published': true,
                                  },
                                ],
                              },
                            ],
                          },
                        ],
                      },
                    ]
                  : key == 'pw_notes_tree'
                  ? tree
                  : key == 'pw_announcement' && !emptyHome
                  ? {
                      'enabled': true,
                      'text': 'Made By Haris (Horizon) with pure Love ❤️',
                    }
                  : [],
              fromCache: false,
            ),
          ),
        ),
      ],
      child: _ReviewApp(initialPath: initialPath),
    ),
  );
}

class _ReviewApp extends ConsumerStatefulWidget {
  const _ReviewApp({required this.initialPath});
  final String initialPath;
  @override
  ConsumerState<_ReviewApp> createState() => _ReviewAppState();
}

class _ReviewAppState extends ConsumerState<_ReviewApp> {
  bool _opened = false;
  @override
  Widget build(BuildContext context) {
    if (!_opened && ref.watch(authStateProvider).hasValue) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(routerProvider).go(widget.initialPath);
      });
    }
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: ColoredBox(
              color: Color(0xFF38383D),
              child: Center(
                child: Text(
                  'UI PREVIEW · SAMPLE DATA',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Outfit',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _ReviewScaledApp()),
        ],
      ),
    );
  }
}

// Only fixture adapters live here. No review credentials or cloud writes.
class _ReviewUser implements User {
  @override
  String get uid => reviewProfile.uid;
  @override
  String? get displayName => reviewProfile.fullName;
  @override
  String? get email => reviewProfile.email;
  @override
  String? get photoURL => null;
  @override
  Future<void> updateDisplayName(String? displayName) async {}
  @override
  Future<void> updatePhotoURL(String? photoURL) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// In-memory administrative sandbox. Never writes to Firebase or persists user data.
class _ReviewAdmin implements AdminRepository {
  _ReviewAdmin(this.notes);
  final List<Map<String, dynamic>> notes;
  final _values = <String, Object?>{};
  final _changes = StreamController<String>.broadcast();
  int _sequence = 0;
  Object? _value(String key) =>
      _values[key] ??
      switch (key) {
        'pw_settings' => <String, dynamic>{},
        'pw_credits' => {'cards': [], 'layout': 'stack'},
        'pw_notes_tree' => notes,
        _ => <dynamic>[],
      };
  Object? _copy(Object? value) => jsonDecode(jsonEncode(value));
  void _set(String key, Object? value) {
    if (key == 'pw_notes_tree' && value is List) {
      notes
        ..clear()
        ..addAll(
          value.whereType<Map>().map((m) => Map<String, dynamic>.from(m)),
        );
    } else {
      _values[key] = value;
    }
    _changes.add(key);
  }

  @override
  Future<Object?> read(String key) async => _copy(_value(key));
  @override
  Stream<Object?> watch(String key) async* {
    yield _copy(_value(key));
    yield* _changes.stream
        .where((k) => k == key)
        .map((_) => _copy(_value(key)));
  }

  @override
  Future<List<Map<String, dynamic>>> tree(LibraryKind kind) async =>
      copyTree(_value(kind.storageKey), kind);
  @override
  Future<Map<String, Object?>> backup() async => {
    for (final key in AdminRepository.writableKeys) key: _copy(_value(key)),
  };
  @override
  Future<void> restore(Map<String, dynamic> backup) async {
    if (backup.keys.any((k) => !AdminRepository.writableKeys.contains(k))) {
      throw const FormatException('Choose a Hyzen backup.');
    }
    for (final entry in backup.entries) {
      _set(entry.key, _copy(entry.value));
    }
  }

  @override
  Future<MergeResult> importRows(
    List<ImportRow> rows,
    List<String> names,
  ) async {
    final batch = 'preview-import-${_sequence++}';
    var added = 0, skipped = 0;
    final conflicts = <String>[];
    for (final key in rows.map((r) => r.storageKey).toSet()) {
      final raw = await read(key);
      final tree = (raw as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final selected = rows.where((r) => r.storageKey == key);
      final result = key == 'pw_lectures_tree'
          ? mergeLectureRows(
              tree,
              selected,
              () => 'preview-${_sequence++}',
              batchId: batch,
            )
          : mergeRows(
              tree,
              selected,
              () => 'preview-${_sequence++}',
              batchId: batch,
            );
      added += result.added;
      skipped += result.skipped;
      conflicts.addAll(result.conflicts);
      _set(key, tree);
    }
    final history = (await read('pw_import_history') as List);
    history.insert(0, {
      'id': batch,
      'status': 'active',
      'touched': rows.map((r) => r.storageKey).toSet().toList(),
      'files': names,
      'added': added,
      'skipped': skipped,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    _set('pw_import_history', history);
    return MergeResult(added, skipped, conflicts);
  }

  @override
  Future<int> undoImport(String id) async {
    final history = (await read('pw_import_history') as List)
        .cast<Map<String, dynamic>>();
    final batch = history.firstWhere((h) => h['id'] == id);
    var removed = 0;
    for (final key in batch['touched'] as List) {
      final tree = (await read(key) as List).cast<Map<String, dynamic>>();
      removed += undoImportNodes(tree, id);
      _set(key, tree);
    }
    batch['status'] = 'undone';
    _set('pw_import_history', history);
    return removed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
    UnsupportedError(
      'Preview only: this administrative action is not connected.',
    ),
  );
}

class _ReviewAuth implements AuthRepository {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authChanges() => Stream.value(null);
  @override
  Future<User> signIn(String email, String password) async =>
      throw UnsupportedError(
        'Open Home from the preview toolbar. No account is needed.',
      );
  @override
  Future<User> createAccount(
    String email,
    String password, {
    String? displayName,
  }) async => throw UnsupportedError('Preview only: accounts are not created.');
  @override
  Future<void> sendReset(String email) async => throw UnsupportedError(
    'Use the normal app preview with your own account for authentication actions.',
  );
  @override
  Future<void> signOut() async => throw UnsupportedError(
    'This UI review uses sample data; there is no authenticated session.',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReviewScaledApp extends StatelessWidget {
  const _ReviewScaledApp();
  @override
  Widget build(BuildContext context) {
    final scale =
        (double.tryParse(Uri.base.queryParameters['textScale'] ?? '') ?? 1)
            .clamp(1.0, 2.0)
            .toDouble();
    return MediaQuery.fromView(
      view: View.of(context),
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations:
                Uri.base.queryParameters['reduceMotion'] == 'true' ||
                MediaQuery.disableAnimationsOf(context),
          ),
          child: const HyzenApp(),
        ),
      ),
    );
  }
}

class _ReviewDownloads extends DownloadsController {
  _ReviewDownloads(this.empty);
  final bool empty;
  @override
  Map<String, DownloadRecord> build() => empty
      ? {}
      : {
          for (var i = 0; i < 5; i++)
            'sample-$i': DownloadRecord(
              key: 'sample-$i',
              kind: LibraryKind.notes,
              title: 'Sample academic document ${i + 1}',
              sourceUrl: 'https://example.org/sample-$i.pdf',
              status: i < 2 ? DownloadStatus.downloading : DownloadStatus.ready,
              progress: i < 2 ? .45 : 1,
              sizeBytes: 450000,
              totalBytes: 1000000,
              localPath: i < 2 ? null : '/sample-data/sample-$i.pdf',
              savedAt: i < 2 ? null : DateTime(2026, 1, 1),
              unopened: i == 2,
            ),
        };
  @override
  Future<void> remove(String key) async =>
      throw UnsupportedError('Sample data preview');
  @override
  Future<void> removeAll() async =>
      throw UnsupportedError('Sample data preview');
  // Sample files cannot be downloaded or deleted from the public UI review.
  @override
  Future<void> save(FileRef file, {String? localPreview}) => Future.error(
    UnsupportedError(
      'Sample data preview; open the Android app to save real files.',
    ),
  );
}

class _ReviewOffice extends PdfStudioRepository {
  _ReviewOffice(this.empty);
  final bool empty;
  @override
  List<StudioFileItem> build() => empty
      ? []
      : [
          for (final (i, title) in [
            'Pharmacology revision notes',
            'Practical notebook · Semester 2',
            'Surgical dressings',
          ].indexed)
            StudioFileItem(
              id: 'review-office-$i',
              originalFileName: '$title.pdf',
              displayName: '$title.pdf',
              internalFilePath: '/sample-data/office-$i.pdf',
              editStateJsonPath: '',
              sourceType: 'IMAGE_SCAN',
              fileCategory: 'PDF',
              fileSizeBytes: 240000 + i * 80000,
              pageCount: 3 + i,
              createdAt: DateTime(2026, 11, 6),
              updatedAt: DateTime(2026, 11, 6),
              operationBadge: 'SCANNED',
            ),
        ];
}

class _ReviewRecent extends RecentController {
  _ReviewRecent(this.empty);
  final bool empty;
  @override
  Future<void> clear() async {
    state = [];
  }

  @override
  List<RecentItem> build() => empty
      ? []
      : [
          RecentItem(
            const FileRef(
              kind: LibraryKind.notes,
              title:
                  'Pharmaceutical Chemistry comprehensive examination revision notes — semester two',
              url: 'https://example.org/review-notes.pdf',
            ),
            DateTime(2026, 1, 3),
          ),
          RecentItem(
            const FileRef(
              kind: LibraryKind.notes,
              title: 'Physical Pharmacy · Surface phenomena',
              url: 'https://example.org/review-physical.pdf',
            ),
            DateTime(2026, 1, 2),
          ),
        ];
}

// Explicit sample board for visual review; no fabricated production rankings.
class _ReviewCampus extends CampusController {
  _ReviewCampus(SharedPreferences prefs, String period, this.setup)
    : super(null, prefs, 'review_rank_$period', period) {
    _render();
  }
  bool setup;
  String display = 'Muhammad Haris';
  bool hidden = false;
  void _render() {
    state = AsyncData(
      CampusBoard(
        setup ? 'Choose your display name.' : 'ready',
        setup || hidden
            ? []
            : const [
                CampusEntry(1, 'Ayesha', 2, 240, 259, 'sample-1'),
                CampusEntry(2, 'Hamza', 2, 180, 195, 'sample-2'),
                CampusEntry(
                  3,
                  'Muhammad Haris',
                  2,
                  120,
                  129,
                  'ui-review-student',
                ),
              ],
        setup || hidden
            ? null
            : CampusEntry(3, display, 2, 120, 129, 'ui-review-student'),
        DateTime.now(),
        academicYear: 2,
        setupRequired: setup,
        verificationRequired: setup,
        optOut: hidden,
        alias: setup ? null : display,
        statusCode: setup
            ? 'setup'
            : hidden
            ? 'private'
            : 'ready',
      ),
    );
  }

  @override
  Future<void> load({bool more = false}) async {}
  @override
  Future<void> privacy(String alias, bool optOut, {int? academicYear}) async {
    display = alias;
    hidden = optOut;
    setup = false;
    _render();
  }
}

import 'dart:convert';
// Opt-in end-to-end test against local emulators. Never connects to production.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyzen_pharmd/features/study_progress/firebase_study_store.dart';
import 'package:hyzen_pharmd/features/study_progress/study_session.dart';

import 'support/firebase_registration.dart';
import 'package:hyzen_pharmd/features/admin/data/admin_repository.dart';
import 'package:hyzen_pharmd/features/admin/domain/import_csv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real Flutter Firebase SDK: claims, confirmed snapshots, file pulses, calendar and retry',
    () async {
      registerFirebaseTestPlugins();
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'fake-api-key',
          appId: '1:123456789:web:emulator',
          messagingSenderId: '123456789',
          projectId: 'demo-hyzen-native',
        ),
      );
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      final user = (await FirebaseAuth.instance.signInAnonymously()).user!;
      final store = FirebaseStudyStore(FirebaseFirestore.instance, user.uid);
      final snapshots = <Map<String, dynamic>>[];
      final subscription = store.watch('rewards').listen(snapshots.add);
      try {
        final state = await store.call('rewardState', {});
        final claimed = await store.call('claimReward', {
          'kind': 'daily',
          'day': state['today'],
        });
        expect(claimed['points'], 100);
        expect(
          (await store.call('claimReward', {
            'kind': 'daily',
            'day': state['today'],
          }))['points'],
          100,
        );
        final session = studyId();
        await store.call('rewardPulse', {
          'session': session,
          'action': 'start',
        });
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await store.call('rewardPulse', {
          'session': session,
          'action': 'heartbeat',
        });
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await store.call('rewardPulse', {
          'session': session,
          'action': 'pause',
        });
        final ref = FirebaseFirestore.instance.doc(
          'studyUsers/${user.uid}/state/activity',
        );
        final paused = (await ref.get(
          const GetOptions(source: Source.server),
        )).data()!;
        expect(paused['totalMs'], greaterThan(0));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await store.call('rewardPulse', {'session': session, 'action': 'stop'});
        final stopped = (await ref.get(
          const GetOptions(source: Source.server),
        )).data()!;
        expect(stopped['totalMs'], paused['totalMs']);
        expect(stopped['closed'], true);
        final calendar = await store.call('calendarEvents', {
          'action': 'save',
          'event': {
            'id': 'exam',
            'title': 'Paper',
            'at': '2026-11-23T04:00:00Z',
            'day': '2026-11-23',
            'color': 0xffd46a61,
            'kind': 'Exam',
            'leadMinutes': 30,
          },
        });
        expect((calendar['events'] as List).single['title'], 'Paper');
        expect(
          (await store.call('calendarEvents', {
            'action': 'delete',
            'id': 'exam',
          }))['events'],
          isEmpty,
        );
        final now = DateTime.now();
        final one = StudyEvent(
          studyId(),
          session,
          now.subtract(const Duration(seconds: 2)),
          now,
          dayKey(now),
        ).toJson();
        final two = StudyEvent(
          studyId(),
          session,
          now,
          now.add(const Duration(seconds: 1)),
          dayKey(now),
        ).toJson();
        expect(
          (await store.call('syncStudy', {
            'events': [one],
          }))['accepted'],
          [one['id']],
        );
        // A lost response followed by queue growth must not acknowledge the unsent tail.
        expect(
          (await store.call('syncStudy', {
            'events': [one, two],
          }))['accepted'],
          [one['id']],
        );
        expect(
          (await store.call('syncStudy', {
            'events': [two],
          }))['accepted'],
          [two['id']],
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(
          snapshots.any((s) => s['todayClaimed'] == true && s['points'] == 100),
          true,
        );
        await store.call('setRankPrivacy', {
          'alias': 'Reader',
          'optOut': false,
          'academicYear': 2,
        });
        final pendingBoard = await store.call('readCampusBoard', {
          'period': 'week',
        });
        expect(pendingBoard['setupRequired'], false);
        expect(pendingBoard['verificationRequired'], true);
        expect(
          (await FirebaseFirestore.instance
                  .doc('campusMemberships/${user.uid}')
                  .get())
              .data()?['verified'],
          false,
        );
        await subscription.cancel();
        // Auth emulator accepts unsigned test tokens; this cannot sign into production.
        await FirebaseAuth.instance.signOut();
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        String encode(Object data) =>
            base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
        const issuer =
            'firebase-adminsdk@demo-hyzen-native.iam.gserviceaccount.com';
        final token =
            '${encode({'alg': 'none', 'typ': 'JWT'})}.${encode({'iss': issuer, 'sub': issuer, 'aud': 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit', 'iat': nowSeconds, 'exp': nowSeconds + 3600, 'uid': 'Vv6HtZjmUvfVACzvuyL2pFx5HR33'})}.';
        await FirebaseAuth.instance.signInWithCustomToken(token);
        final admin = AdminRepository(FirebaseFirestore.instance, () => true);
        final rows = validateImport(
          'Type,Professional Year,Semester,Subject,Section,Topic,File Name,Link\nNotes,2nd Professional,Semester 1,Pharmacology,Notes,ANS,Revision,https://example.org/revision.pdf',
          'real-admin.csv',
        ).rows;
        final imported = await admin.importRows(rows, ['real-admin.csv']);
        expect(imported.added, 1);
        expect((await admin.importRows(rows, ['retry.csv'])).skipped, 1);
        final backup = await admin.backup();
        expect(jsonEncode(backup), contains('Revision'));
        final history = (await admin.read('pw_import_history') as List);
        final first = history.firstWhere((h) => h['added'] == 1);
        expect(await admin.undoImport(first['id']), 1);
        expect(
          jsonEncode(await admin.read('pw_notes_tree')),
          isNot(contains('Revision')),
        );
        await admin.restore(Map<String, dynamic>.from(backup));
        expect(
          jsonEncode(await admin.read('pw_notes_tree')),
          contains('Revision'),
        );
        await admin.setProfessionalVerification(user.uid, 2, true);
        expect(
          (await FirebaseFirestore.instance
                  .doc('campusMemberships/${user.uid}')
                  .get())
              .data()?['verified'],
          true,
        );

        // Legacy D1 opt-out never becomes an automatic Firebase opt-in.
        final readerToken =
            '${encode({'alg': 'none', 'typ': 'JWT'})}.${encode({'iss': issuer, 'sub': issuer, 'aud': 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit', 'iat': nowSeconds, 'exp': nowSeconds + 3600, 'uid': user.uid})}.';
        await FirebaseAuth.instance.signInWithCustomToken(readerToken);
        expect(
          (await store.call('readCampusBoard', {'period': 'week'}))['status'],
          'ready',
        );
        await store.call('setRankPrivacy', {
          'alias': 'Reader',
          'optOut': false,
        });
        expect(
          (await store.call('readCampusBoard', {'period': 'week'}))['status'],
          'ready',
        );
        final rankedSession = studyId();
        await store.call('rewardPulse', {
          'session': rankedSession,
          'action': 'start',
        });
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await store.call('rewardPulse', {
          'session': rankedSession,
          'action': 'heartbeat',
        });
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await store.call('rewardPulse', {
          'session': rankedSession,
          'action': 'pause',
        });
        final ledger =
            (await FirebaseFirestore.instance
                    .doc('studyUsers/${user.uid}/state/rank_2')
                    .get())
                .data()!;
        expect(ledger['sourceVersion'], greaterThan(0));
        expect(
          (await FirebaseFirestore.instance
                  .doc('professionalRanks/${user.uid}')
                  .get())
              .data()?['academicYear'],
          2,
        );
        await store.call('setRankPrivacy', {'alias': 'Reader', 'optOut': true});
        expect(
          (await FirebaseFirestore.instance
                  .doc('professionalRanks/${user.uid}')
                  .get())
              .exists,
          false,
        );
      } finally {
        await subscription.cancel();
        await FirebaseAuth.instance.signOut();
      }
    },
    skip: !const bool.fromEnvironment('HYZEN_FIREBASE_EMULATOR_TEST'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

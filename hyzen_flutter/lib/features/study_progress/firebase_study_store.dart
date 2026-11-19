import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'study_session.dart';

/// Firebase Auth identifies the owner; Firestore rules validate every credit
/// against immutable, server-stamped pulse intervals. No Worker or Functions.
class FirebaseStudyStore {
  FirebaseStudyStore(this.db, this.uid);
  final FirebaseFirestore db;
  final String uid;
  Duration _offset = Duration.zero;
  bool _clockReady = false;
  final Map<String, Map<int, DocumentSnapshot<Map<String, dynamic>>>> _cursors =
      {};
  CollectionReference<Map<String, dynamic>> get _state =>
      db.collection('studyUsers').doc(uid).collection('state');
  DocumentReference<Map<String, dynamic>> get _member =>
      db.collection('campusMemberships').doc(uid);
  DocumentReference<Map<String, dynamic>> get _public =>
      db.collection('professionalRanks').doc(uid);
  static int number(Object? value) => (value as num?)?.toInt() ?? 0;
  static int epochDay(DateTime date) =>
      (date.toUtc().millisecondsSinceEpoch + 18000000) ~/ 86400000;
  static String dateForDay(int day) => DateTime.fromMillisecondsSinceEpoch(
    day * 86400000,
    isUtc: true,
  ).toIso8601String().substring(0, 10);
  static int weekForDay(int day) => (day + 3) ~/ 7;
  static int monthForDay(int day) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      day * 86400000,
      isUtc: true,
    );
    return date.year * 12 + date.month;
  }

  static bool eligible(Map<String, dynamic>? member) =>
      member?['verified'] == true &&
      member?['firebaseRankConsent'] == true &&
      member?['optOut'] == false &&
      number(member?['academicYear']) >= 1 &&
      number(member?['academicYear']) <= 5;
  Future<DateTime> _serverTime() async {
    final ref = _state.doc('clock');
    await ref.set({'at': FieldValue.serverTimestamp()});
    final stamp =
        (await ref.get(const GetOptions(source: Source.server))).data()?['at']
            as Timestamp;
    _offset = stamp.toDate().difference(DateTime.now());
    _clockReady = true;
    return stamp.toDate();
  }

  DateTime get _now => DateTime.now().add(_offset);
  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> data,
  ) async => switch (method) {
    'syncStudy' => _syncEvents(data),
    'rewardState' => rewardState(),
    'claimReward' => _claim(data),
    'rewardPulse' => _pulse(data),
    'studyPulse' => data['action'] == 'stop' ? _pulse(data) : _studyStatus(),
    'calendarEvents' => _calendar(data),
    'readCampusBoard' => _board(data),
    'setRankPrivacy' => _privacy(data),
    _ => throw StateError('This study action is not available.'),
  };
  Stream<Map<String, dynamic>> watch(String topic) {
    if (topic == 'rewards') {
      return _state
          .where(FieldPath.documentId, whereIn: ['wallet', 'activity'])
          .snapshots(includeMetadataChanges: true)
          .where((s) => !s.metadata.hasPendingWrites)
          .map((s) => _rewardData({for (final d in s.docs) d.id: d.data()}));
    }
    if (topic == 'calendar') {
      return db
          .collection('studyUsers')
          .doc(uid)
          .collection('calendar')
          .snapshots(includeMetadataChanges: true)
          .map(
            (s) => {
              'events': [
                for (final d in s.docs)
                  {...d.data()..remove('updatedAt'), 'id': d.id},
              ],
            },
          );
    }
    if (topic == 'history') {
      return db
          .collection('studyUsers')
          .doc(uid)
          .collection('eventBatches')
          .snapshots(includeMetadataChanges: true)
          .where((s) => !s.metadata.hasPendingWrites)
          .map(
            (s) => {
              'events': [
                for (final change in s.docChanges)
                  if (change.type != DocumentChangeType.removed)
                    ...change.doc.data()?['events'] as List? ?? [],
              ],
            },
          );
    }
    final controller = StreamController<Map<String, dynamic>>();
    StreamSubscription? memberSubscription, rankSubscription;
    controller.onListen = () {
      memberSubscription = _member
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
            rankSubscription?.cancel();
            controller.add({});
            final m = snapshot.data();
            if (!eligible(m)) return;
            final period = topic.replaceFirst('rank:', ''),
                day = epochDay(_now);
            Query<Map<String, dynamic>> query = db
                .collection('professionalRanks')
                .where('academicYear', isEqualTo: number(m?['academicYear']))
                .where('verified', isEqualTo: true)
                .where('optOut', isEqualTo: false);
            final prefix = period == 'semester' ? 'total' : period;
            if (prefix != 'total') {
              query = query.where(
                '${prefix}Key',
                isEqualTo: prefix == 'week'
                    ? weekForDay(day)
                    : monthForDay(day),
              );
            }
            rankSubscription = query
                .where('${prefix}Points', isGreaterThan: 0)
                .orderBy('${prefix}Points', descending: true)
                .orderBy('${prefix}Minutes', descending: true)
                .orderBy('uid')
                .limit(30)
                .snapshots(includeMetadataChanges: true)
                .where((s) => !s.metadata.hasPendingWrites)
                .listen(
                  (_) => controller.add({}),
                  onError: controller.addError,
                );
          }, onError: controller.addError);
    };
    controller.onCancel = () async {
      await memberSubscription?.cancel();
      await rankSubscription?.cancel();
    };
    return controller.stream;
  }

  Future<Map<String, dynamic>> _syncEvents(Map<String, dynamic> input) async {
    final events = (input['events'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (events.length > 100) throw StateError('Sync at most 100 intervals.');
    // One immutable batch rather than a document/write for every single second.
    final encoded = events.map((e) => StudyEvent.fromJson(e)).toList();
    if (encoded.isEmpty) return {'accepted': <String>[]};
    final id = encoded.first.id;
    final ref = db
        .collection('studyUsers')
        .doc(uid)
        .collection('eventBatches')
        .doc(id);
    final accepted = await db.runTransaction<List<String>>((tx) async {
      final prior = (await tx.get(ref)).data();
      if (prior != null) {
        final existing = (prior['events'] as List).map((e) => e['id']).toSet();
        return encoded
            .where((e) => existing.contains(e.id))
            .map((e) => e.id)
            .toList();
      }
      tx.set(ref, {
        'events': [for (final e in encoded) e.toJson()],
        'receivedAt': FieldValue.serverTimestamp(),
      });
      return encoded.map((e) => e.id).toList();
    });
    return {'accepted': accepted};
  }

  Map<String, dynamic> _rewardData(Map<String, Map<String, dynamic>> docs) {
    final wallet = docs['wallet'] ?? {}, activity = docs['activity'] ?? {};
    final last = number(wallet['lastDay']),
        today = epochDay(_now),
        streak = number(wallet['streak']);
    final studyMs = number(activity['totalMs']);
    final stamps = [
      wallet['updatedAt'],
      activity['at'],
    ].whereType<Timestamp>().map((s) => s.millisecondsSinceEpoch);
    return {
      'today': dateForDay(today),
      'updatedAt': stamps.fold<int>(0, math.max),
      'points': number(wallet['points']) + studyMs * 100 ~/ 3600000,
      'studyPoints': studyMs * 100 ~/ 3600000,
      'studySeconds': studyMs ~/ 1000,
      'claimedDays': [
        for (final d in wallet['days'] as List? ?? []) dateForDay(number(d)),
      ],
      'claimedMilestones': wallet['badges'] ?? [],
      'streak': last >= today - 1 ? streak : 0,
      'bestStreak': number(wallet['best']),
      'todayClaimed': last == today,
      'timezone': 'Asia/Karachi',
    };
  }

  Future<Map<String, dynamic>> rewardState() async {
    if (!_clockReady) await _serverTime();
    final docs = await Future.wait([
      _state.doc('wallet').get(const GetOptions(source: Source.server)),
      _state.doc('activity').get(const GetOptions(source: Source.server)),
    ]);
    return _rewardData({
      for (final d in docs)
        if (d.exists) d.id: d.data()!,
    });
  }

  Future<Map<String, dynamic>> _claim(Map<String, dynamic> input) async {
    final now = await _serverTime(), day = epochDay(now);
    if (input['day'] != dateForDay(day)) {
      throw StateError('Refresh and claim today’s points.');
    }
    final ref = _state.doc('wallet');
    await db.runTransaction((tx) async {
      final old =
          (await tx.get(ref)).data() ??
          {
            'points': 0,
            'lastDay': -1,
            'streak': 0,
            'best': 0,
            'days': <int>[],
            'badges': <int>[],
          };
      final next = Map<String, dynamic>.from(old);
      if (input['kind'] == 'daily') {
        if (number(old['lastDay']) == day) return;
        final streak = number(old['lastDay']) == day - 1
            ? number(old['streak']) + 1
            : 1;
        next.addAll({
          'action': 'daily',
          'points': number(old['points']) + 100 + (streak % 7 == 0 ? 200 : 0),
          'lastDay': day,
          'streak': streak,
          'best': math.max(number(old['best']), streak),
          'days': [...old['days'] as List, day],
          'milestone': 0,
        });
      } else {
        final milestone = number(input['milestone']);
        if (![5, 7, 14, 30, 60, 100].contains(milestone) ||
            number(old['best']) < milestone) {
          throw StateError('Achievement is still locked.');
        }
        if ((old['badges'] as List).contains(milestone)) return;
        next.addAll({
          'action': 'achievement',
          'milestone': milestone,
          'points': number(old['points']) + 50,
          'badges': [...old['badges'] as List, milestone],
        });
      }
      next['updatedAt'] = FieldValue.serverTimestamp();
      tx.set(ref, next);
    });
    return rewardState();
  }

  DocumentReference<Map<String, dynamic>> _day(int year, int day) => db
      .collection('studyUsers')
      .doc(uid)
      .collection('verifiedDays')
      .doc('${year}_$day');
  Map<String, dynamic> _emptyRank(int year) => {
    'academicYear': year,
    'weekKey': 0,
    'weekPoints': 0,
    'weekMinutes': 0,
    'monthKey': 0,
    'monthPoints': 0,
    'monthMinutes': 0,
    'totalPoints': 0,
    'totalMinutes': 0,
    'sourceVersion': 0,
  };
  Future<Map<String, dynamic>> _pulse(Map<String, dynamic> input) async {
    final session = input['session'] as String?, action = input['action'];
    if (session == null ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(session) ||
        !['start', 'heartbeat', 'pause', 'stop'].contains(action)) {
      throw StateError('Invalid study pulse.');
    }
    if (action == 'stop') await _advance(session, 'pause');
    await _advance(session, action as String);
    if (action == 'pause') await _advance(session, 'settle');
    return rewardState();
  }

  Future<void> _advance(String session, String action) async {
    final ref = _state.doc('activity');
    await db.runTransaction((tx) async {
      final old = (await tx.get(ref)).data();
      final member = (await tx.get(_member)).data();
      final year = member?['verified'] == true
          ? number(member?['academicYear'])
          : 0;
      if (old == null) {
        if (action != 'start') return;
        tx.set(ref, {
          'version': 1,
          'session': session,
          'active': true,
          'closed': false,
          'at': FieldValue.serverTimestamp(),
          'previousAt': FieldValue.serverTimestamp(),
          'previousActive': false,
          'previousSession': session,
          'totalMs': 0,
          'sessionMs': 0,
          'deltaMs': 0,
          'creditDay': 0,
          'creditYear': 0,
          'completion': 0,
          'academicYear': year,
        });
        return;
      }
      if (action != 'start' && old['session'] != session) {
        throw StateError('Start this file session first.');
      }
      if (old['active'] == true &&
          old['session'] != session &&
          _now.difference((old['at'] as Timestamp).toDate()).inSeconds < 30) {
        throw StateError('Another device is already studying.');
      }
      if (old['closed'] == true && action != 'start') return;
      final at = old['at'] as Timestamp,
          previous = old['previousAt'] as Timestamp;
      final gap = at.millisecondsSinceEpoch - previous.millisecondsSinceEpoch;
      final day = epochDay(at.toDate()),
          creditYear = number(old['academicYear']);
      final delta =
          old['previousActive'] == true &&
              old['previousSession'] == old['session'] &&
              gap >= 0 &&
              gap <= 30000 &&
              day == epochDay(previous.toDate())
          ? gap
          : 0;
      final sessionMs = old['session'] == session
          ? number(old['sessionMs']) + delta
          : 0;
      final completion =
          action == 'stop' && old['closed'] != true && sessionMs >= 600000
          ? 1
          : 0;
      final version = number(old['version']) + 1;
      Map<String, dynamic>? dayRecord, yesterday, rank;
      final ledger = _state.doc('rank_$year');
      if (delta > 0 || completion > 0) {
        dayRecord = (await tx.get(_day(creditYear, day))).data();
        yesterday = (await tx.get(_day(creditYear, day - 1))).data();
        if (eligible(member) && year == creditYear) {
          rank = (await tx.get(ledger)).data();
        }
      }
      final next = {
        'version': version,
        'session': session,
        'active': action == 'start' || action == 'heartbeat',
        'closed': action == 'stop',
        'at': FieldValue.serverTimestamp(),
        'previousAt': at,
        'previousActive': old['active'] == true,
        'previousSession': old['session'],
        'totalMs': number(old['totalMs']) + delta,
        'sessionMs': sessionMs,
        'deltaMs': delta,
        'creditDay': day,
        'creditYear': creditYear,
        'completion': completion,
        'academicYear': year,
      };
      tx.set(ref, next);
      if (delta == 0 && completion == 0) return;
      final beforeMs = number(dayRecord?['totalMs']),
          afterMs = beforeMs + delta;
      final beforeSessions = number(dayRecord?['completed']),
          afterSessions = beforeSessions + completion;
      final beforeBonus = number(dayRecord?['bonus']);
      final afterBonus =
          afterMs >= 900000 && number(yesterday?['totalMs']) >= 900000
          ? 5
          : beforeBonus;
      final oldMinutes = math.min(360, beforeMs ~/ 60000),
          newMinutes = math.min(360, afterMs ~/ 60000);
      final points =
          newMinutes -
          oldMinutes +
          2 * (math.min(5, afterSessions) - math.min(5, beforeSessions)) +
          afterBonus -
          beforeBonus;
      tx.set(_day(creditYear, day), {
        'day': day,
        'academicYear': creditYear,
        'totalMs': afterMs,
        'completed': afterSessions,
        'bonus': afterBonus,
        'lastVersion': version,
      });
      if (!eligible(member) || year != creditYear) return;
      final prior = rank ?? _emptyRank(year),
          week = weekForDay(day),
          month = monthForDay(day);
      final stats = {
        'academicYear': year,
        'weekKey': week,
        'weekPoints':
            (prior['weekKey'] == week ? number(prior['weekPoints']) : 0) +
            points,
        'weekMinutes':
            (prior['weekKey'] == week ? number(prior['weekMinutes']) : 0) +
            newMinutes -
            oldMinutes,
        'monthKey': month,
        'monthPoints':
            (prior['monthKey'] == month ? number(prior['monthPoints']) : 0) +
            points,
        'monthMinutes':
            (prior['monthKey'] == month ? number(prior['monthMinutes']) : 0) +
            newMinutes -
            oldMinutes,
        'totalPoints': number(prior['totalPoints']) + points,
        'totalMinutes': number(prior['totalMinutes']) + newMinutes - oldMinutes,
        'sourceVersion': version,
      };
      tx.set(ledger, stats);
      tx.set(_public, {
        ...stats,
        'uid': uid,
        'alias': member?['alias'] ?? 'Student',
        'verified': true,
        'optOut': false,
      });
    });
  }

  Future<Map<String, dynamic>> _studyStatus() async {
    final activity =
        (await _state
                .doc('activity')
                .get(const GetOptions(source: Source.server)))
            .data();
    return {
      'status': 'Study history synced',
      'seconds': number(activity?['sessionMs']) ~/ 1000,
    };
  }

  Future<Map<String, dynamic>> _calendar(Map<String, dynamic> input) async {
    final collection = db
        .collection('studyUsers')
        .doc(uid)
        .collection('calendar');
    if (input['action'] == 'save') {
      final event = Map<String, dynamic>.from(input['event'] as Map);
      final id = event.remove('id') as String;
      await collection.doc(id).set({
        ...event,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (input['action'] == 'delete') {
      await collection.doc(input['id'] as String).delete();
    }
    final docs = await collection.get(const GetOptions(source: Source.server));
    return {
      'events': [
        for (final d in docs.docs)
          {...d.data()..remove('updatedAt'), 'id': d.id},
      ],
    };
  }

  Future<Map<String, dynamic>> _privacy(Map<String, dynamic> input) async {
    final alias = '${input['alias'] ?? ''}'.trim(), optOut = input['optOut'];
    if (alias.isEmpty || alias.length > 40 || optOut is! bool) {
      throw StateError('Choose a valid ranking alias.');
    }
    await db.runTransaction((tx) async {
      final member = (await tx.get(_member)).data();
      final verified = member?['verified'] == true;
      final requestedYear = number(input['academicYear']);
      final year = verified
          ? number(member?['academicYear'])
          : (requestedYear >= 1 && requestedYear <= 5
                ? requestedYear
                : number(member?['academicYear']));
      if (year < 1 || year > 5) {
        throw StateError('Choose your professional year.');
      }
      final ledger = verified
          ? (await tx.get(_state.doc('rank_$year'))).data() ?? _emptyRank(year)
          : _emptyRank(year);
      final preferences = <String, dynamic>{
        'alias': alias,
        'optOut': optOut,
        'privacyUpdatedAt': FieldValue.serverTimestamp(),
        'firebaseRankConsent': true,
        if (!verified) 'requestedYear': year,
        if (!verified) 'verificationRequestedAt': FieldValue.serverTimestamp(),
      };
      if (member == null) {
        tx.set(_member, {
          ...preferences,
          'verified': false,
          'academicYear': year,
        });
      } else {
        tx.update(_member, preferences);
      }
      if (optOut || !verified) {
        tx.delete(_public);
      } else {
        tx.set(_public, {
          ...ledger,
          'uid': uid,
          'alias': alias,
          'verified': true,
          'optOut': false,
        });
      }
    });
    return {'saved': true};
  }

  Future<Map<String, dynamic>> _board(Map<String, dynamic> input) async {
    final member = (await _member.get(
      const GetOptions(source: Source.server),
    )).data();
    final setupRequired = member?['firebaseRankConsent'] != true;
    final verificationRequired = member?['verified'] != true;
    final privacy = <String, dynamic>{
      'setupRequired': setupRequired,
      'verificationRequired': verificationRequired,
      'optOut': member?['optOut'] != false,
      'alias': member?['alias'],
      'academicYear': verificationRequired
          ? (member?['requestedYear'] ?? member?['academicYear'])
          : (member?['academicYear']),
    };
    if (!eligible(member)) {
      return {
        ...privacy,
        'statusCode': setupRequired
            ? 'setup'
            : verificationRequired
            ? 'review'
            : 'private',
        'status': setupRequired
            ? 'Choose your ranking name and visibility.'
            : verificationRequired
            ? 'Your professional year is awaiting review.'
            : 'Your ranking profile is private.',
        'entries': <Map<String, dynamic>>[],
        'mine': null,
      };
    }
    await _ensureProjection();
    final period = input['period'];
    if (!['week', 'month', 'semester'].contains(period)) {
      throw StateError('Invalid ranking period.');
    }
    final year = number(member?['academicYear']),
        day = epochDay(_now),
        prefix = period == 'semester' ? 'total' : period;
    final periodKey = period == 'week'
        ? weekForDay(day)
        : period == 'month'
        ? monthForDay(day)
        : year;
    final generation =
        '$year:$period:$periodKey:${_now.millisecondsSinceEpoch ~/ 15000}';
    if (input['generation'] != null && input['generation'] != generation) {
      return {'status': 'refresh', 'entries': [], 'mine': null};
    }
    Query<Map<String, dynamic>> query = db
        .collection('professionalRanks')
        .where('academicYear', isEqualTo: year)
        .where('verified', isEqualTo: true)
        .where('optOut', isEqualTo: false);
    if (period != 'semester') {
      query = query.where('${prefix}Key', isEqualTo: periodKey);
    }
    final ordered = query
        .where('${prefix}Points', isGreaterThan: 0)
        .orderBy('${prefix}Points', descending: true)
        .orderBy('${prefix}Minutes', descending: true)
        .orderBy('uid');
    final after = number(input['after']),
        cursors = _cursors.putIfAbsent(generation, () => {});
    if (after > 0 && !cursors.containsKey(after)) {
      return {'status': 'refresh', 'entries': [], 'mine': null};
    }
    final page =
        await (after > 0
                ? ordered.startAfterDocument(cursors[after]!).limit(30)
                : ordered.limit(30))
            .get(const GetOptions(source: Source.server));
    Map<String, dynamic> entry(Map<String, dynamic> data, int rank) => {
      'uid': data['uid'],
      'alias': data['alias'],
      'academicYear': year,
      'verifiedMinutes': data['${prefix}Minutes'],
      'score': data['${prefix}Points'],
      'rank': rank,
    };
    final entries = [
      for (var i = 0; i < page.docs.length; i++)
        entry(page.docs[i].data(), after + i + 1),
    ];
    if (page.docs.isNotEmpty) {
      cursors[after + page.docs.length] = page.docs.last;
    }
    final own = (await _public.get(
      const GetOptions(source: Source.server),
    )).data();
    Map<String, dynamic>? mine;
    if (own != null &&
        own['academicYear'] == year &&
        (period == 'semester' || own['${prefix}Key'] == periodKey) &&
        number(own['${prefix}Minutes']) > 0) {
      final points = number(own['${prefix}Points']),
          minutes = number(own['${prefix}Minutes']);
      final counts = await Future.wait([
        query.where('${prefix}Points', isGreaterThan: points).count().get(),
        query
            .where('${prefix}Points', isEqualTo: points)
            .where('${prefix}Minutes', isGreaterThan: minutes)
            .count()
            .get(),
        query
            .where('${prefix}Points', isEqualTo: points)
            .where('${prefix}Minutes', isEqualTo: minutes)
            .where('uid', isLessThan: uid)
            .count()
            .get(),
      ]);
      mine = entry(own, 1 + counts.fold<int>(0, (n, c) => n + (c.count ?? 0)));
    }
    _cursors.removeWhere((key, _) => key != generation);
    return {
      ...privacy,
      'status': 'ready',
      'statusCode': 'ready',
      'academicYear': year,
      'entries': entries,
      'mine': mine,
      'updatedAt': _now.millisecondsSinceEpoch,
      'generation': generation,
      'next': page.docs.length == 30 ? after + 30 : null,
    };
  }

  Future<void> _ensureProjection() => db.runTransaction((tx) async {
    final member = (await tx.get(_member)).data();
    if (!eligible(member)) return;
    final year = number(member?['academicYear']);
    final public = (await tx.get(_public)).data();
    final ledger = (await tx.get(_state.doc('rank_$year'))).data();
    if (public?['academicYear'] == year &&
        public?['alias'] == (member?['alias'] ?? 'Student')) {
      return;
    }
    tx.set(_public, {
      ...ledger ?? _emptyRank(year),
      'uid': uid,
      'alias': member?['alias'] ?? 'Student',
      'verified': true,
      'optOut': false,
    });
  });
}

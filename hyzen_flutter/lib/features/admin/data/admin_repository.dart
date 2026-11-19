import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_error.dart';
import '../../academics/domain/models.dart';
import '../../shop/data/shop_controllers.dart';
import '../domain/import_csv.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(
    ref.watch(firestoreProvider),
    () => ref.read(isAdminProvider),
  );
});

final adminTreeProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, LibraryKind>(
      (ref, kind) => ref.watch(adminRepositoryProvider).tree(kind),
    );

/// Only explicit administrator actions may write legacy settings documents.
/// Every edit starts from the server's latest value inside a transaction.
class AdminRepository {
  AdminRepository(this._db, this._isAdmin);
  final FirebaseFirestore _db;
  final bool Function() _isAdmin;
  void _guard() {
    if (!_isAdmin()) {
      throw FriendlyException('Administrator access is required.');
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String key) =>
      _db.collection('settings').doc(key);

  Stream<List<Map<String, dynamic>>> professionalMemberships() {
    _guard();
    return _db
        .collection('campusMemberships')
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs) {...doc.data(), 'uid': doc.id},
          ],
        );
  }

  /// Invalidate the public projection atomically when verification changes.
  /// The owner can then restore it from their validated, private year ledger.
  Future<void> setProfessionalVerification(
    String uid,
    int year,
    bool verified,
  ) async {
    _guard();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(uid) ||
        year < 1 ||
        year > 5) {
      throw FriendlyException(
        'Choose a valid account UID and professional year.',
      );
    }
    final member = _db.collection('campusMemberships').doc(uid);
    await _db.runTransaction((tx) async {
      _guard();
      final old = (await tx.get(member)).data() ?? <String, dynamic>{};
      tx.delete(_db.collection('professionalRanks').doc(uid));
      tx.set(member, {
        ...old,
        'academicYear': year,
        'verified': verified,
        'alias': old['alias'] ?? 'Student',
        'optOut': old['optOut'] ?? true,
        'verificationUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void _checkSize(Object value) {
    if (utf8.encode(jsonEncode(value)).length > 950 * 1024) {
      throw FriendlyException(
        'This library is near the database document limit. Split the library before adding more files.',
      );
    }
  }

  static const writableKeys = {
    'pw_settings',
    'pw_notes_tree',
    'pw_lectures_tree',
    'pw_mcqs_tree',
    'pw_special_tree',
    'pw_pastpapers',
    'pw_products',
    'pw_blogs',
    'pw_announcement',
    'pw_catalog_settings',
    'pw_delivery',
    'pw_stats',
    'pw_social',
    'pw_credits',
    'pw_about',
    'pw_orders',
    'pw_messages',
    'pw_users',
    'pw_import_history',
  };
  void _key(String key) {
    _guard();
    if (!writableKeys.contains(key)) {
      throw FriendlyException('Unsupported data section.');
    }
  }

  Future<Object?> read(String key) async {
    _key(key);
    return (await _doc(
      key,
    ).get(const GetOptions(source: Source.server))).data()?['value'];
  }

  Stream<Object?> watch(String key) {
    _key(key);
    return _doc(key).snapshots().map((s) => s.data()?['value']);
  }

  Future<void> patch(String key, Map<String, dynamic> updates) async {
    _key(key);
    await _db.runTransaction((tx) async {
      _key(key);
      final doc = _doc(key);
      final snap = await tx.get(doc);
      final value = Map<String, dynamic>.from(
        (snap.data()?['value'] as Map?) ?? {},
      );
      for (final entry in updates.entries) {
        setPath(value, entry.key, entry.value);
      }
      _checkSize(value);
      tx.set(doc, {
        'value': value,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    });
  }

  Future<void> changeList(
    String key,
    void Function(List<Map<String, dynamic>>) change, {
    String? nested,
  }) async {
    _key(key);
    await _db.runTransaction((tx) async {
      _key(key);
      final doc = _doc(key);
      final snap = await tx.get(doc);
      final raw = snap.data()?['value'];
      final wrapper = nested == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(raw is Map ? raw : {});
      final data = nested == null ? raw : wrapper[nested];
      final list = (data is List ? data : [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      change(list);
      final Object value;
      if (nested == null) {
        value = list;
      } else {
        wrapper[nested] = list;
        value = wrapper;
      }
      _checkSize(value);
      tx.set(doc, {
        'value': value,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    });
  }

  Future<void> updateOrder(
    String id,
    Map<String, dynamic> updates, {
    bool remove = false,
  }) async {
    _guard();
    await _db.runTransaction((tx) async {
      _guard();
      final doc = _doc('pw_orders');
      final snap = await tx.get(doc);
      final list = (snap.data()?['value'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final order = list.where((m) => m['id'] == id).firstOrNull;
      if (order == null) {
        throw FriendlyException('Order no longer exists. Refresh the list.');
      }
      if (remove) {
        list.remove(order);
      } else {
        order.addAll(updates);
      }
      _checkSize(list);
      tx.set(doc, {
        'value': list,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      final token = order['verifyToken'];
      if (token is String && token.isNotEmpty) {
        final verification = _db.collection('verifications').doc(token);
        if (remove) {
          tx.delete(verification);
        } else {
          tx.set(verification, publicOrder(order), SetOptions(merge: true));
        }
      }
    });
  }

  /// Canonical orders/messages and inbox deletions commit together. Retries cannot double-decrement stock.
  Future<int> syncInboxes() async {
    _guard();
    final orders = await _db
        .collection('orders_inbox')
        .limit(100)
        .get(const GetOptions(source: Source.server));
    final messages = await _db
        .collection('messages_inbox')
        .limit(100)
        .get(const GetOptions(source: Source.server));
    return _db.runTransaction((tx) async {
      _guard();
      final od = _doc('pw_orders'),
          pd = _doc('pw_products'),
          md = _doc('pw_messages');
      final os = await tx.get(od), ps = await tx.get(pd), ms = await tx.get(md);
      final inboxOrders = <Map<String, dynamic>>[],
          inboxMessages = <Map<String, dynamic>>[];
      final delete = <DocumentReference<Map<String, dynamic>>>[];
      for (final d in [...orders.docs, ...messages.docs]) {
        final fresh = await tx.get(d.reference);
        if (!fresh.exists) continue;
        final raw = fresh.data()?['value'];
        if (raw is! Map || raw['id'] == null) continue;
        (d.reference.parent.id == 'orders_inbox' ? inboxOrders : inboxMessages)
            .add(Map<String, dynamic>.from(raw));
        delete.add(d.reference);
      }
      List<Map<String, dynamic>> list(Object? raw) => (raw is List ? raw : [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      final canonical = list(os.data()?['value']),
          products = list(ps.data()?['value']),
          canonicalMessages = list(ms.data()?['value']);
      final added = mergeOrderInbox(canonical, products, inboxOrders);
      for (final message in inboxMessages) {
        if (!canonicalMessages.any((m) => m['id'] == message['id'])) {
          canonicalMessages.add(message);
        }
      }
      for (final value in [canonical, products, canonicalMessages]) {
        _checkSize(value);
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      if (inboxOrders.isNotEmpty) {
        tx.set(od, {
          'value': canonical,
          'updatedAt': stamp,
        }, SetOptions(merge: true));
        tx.set(pd, {
          'value': products,
          'updatedAt': stamp,
        }, SetOptions(merge: true));
        for (final o in canonical.where(
          (m) => inboxOrders.any((i) => i['id'] == m['id']),
        )) {
          final token = o['verifyToken'];
          if (token is String && token.isNotEmpty) {
            tx.set(
              _db.collection('verifications').doc(token),
              publicOrder(o),
              SetOptions(merge: true),
            );
          }
        }
      }
      if (inboxMessages.isNotEmpty) {
        tx.set(md, {
          'value': canonicalMessages,
          'updatedAt': stamp,
        }, SetOptions(merge: true));
      }
      for (final doc in delete) {
        tx.delete(doc);
      }
      return added + inboxMessages.length;
    });
  }

  Future<Map<String, Object?>> backup() async {
    _guard();
    final map = <String, Object?>{};
    for (final key in writableKeys) {
      map[key] = await read(key);
    }
    return map;
  }

  Future<void> restore(Map<String, dynamic> backup) async {
    _guard();
    if (backup.isEmpty || backup.keys.any((k) => !writableKeys.contains(k))) {
      throw FriendlyException('Choose a valid Hyzen backup.');
    }
    for (final value in backup.values) {
      if (value != null) _checkSize(value);
    }
    final batch = _db.batch();
    for (final entry in backup.entries) {
      if (entry.value == null) continue;
      batch.set(_doc(entry.key), {
        'value': entry.value,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> tree(LibraryKind kind) async {
    _guard();
    final snap = await _doc(
      kind.storageKey,
    ).get(const GetOptions(source: Source.server));
    return copyTree(snap.data()?['value'], kind);
  }

  Future<void> updateSections(Map<String, bool> updates) async {
    _guard();
    const allowed = {
      'notesEnabled',
      'mcqsEnabled',
      'specialEnabled',
      'papersEnabled',
      'lecturesEnabled',
      'shopEnabled',
      'blogEnabled',
      'aboutEnabled',
      'shopComingSoon',
    };
    if (updates.keys.any((k) => !allowed.contains(k))) {
      throw FriendlyException('Invalid section setting.');
    }
    await _db.runTransaction((tx) async {
      _guard();
      final doc = _doc('pw_settings');
      final snap = await tx.get(doc);
      final value = snap.data()?['value'];
      final map = value is Map
          ? Map<String, dynamic>.from(value)
          : <String, dynamic>{};
      tx.set(doc, {
        'value': {...map, ...updates},
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    });
  }

  Future<void> editTree(
    LibraryKind kind,
    void Function(List<Map<String, dynamic>>) edit,
  ) async {
    _guard();
    await _db.runTransaction((tx) async {
      _guard();
      final doc = _doc(kind.storageKey);
      final snap = await tx.get(doc);
      final value = copyTree(snap.data()?['value'], kind);
      edit(value);
      _checkSize(value);
      tx.set(doc, {
        'value': value,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    });
  }

  Future<MergeResult> importRows(
    List<ImportRow> rows,
    List<String> names,
  ) async {
    _guard();
    if (rows.isEmpty || rows.length > 2000) {
      throw FriendlyException('Choose 1 to 2,000 valid rows.');
    }
    final batchId = legacyUid('import');
    final kinds = rows.map((r) => r.storageKey).toSet().toList();
    return _db.runTransaction((tx) async {
      _guard();
      // Read all docs before any writes, as required by Firestore transactions.
      final docs = {for (final k in kinds) k: _doc(k)};
      final values = <String, List<Map<String, dynamic>>>{};
      for (final k in kinds) {
        final raw = (await tx.get(docs[k]!)).data()?['value'];
        values[k] = k == 'pw_lectures_tree'
            ? (raw is List ? raw : [])
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList()
            : copyTree(
                raw,
                LibraryKind.values.firstWhere((kind) => kind.storageKey == k),
              );
      }
      final historyDoc = _doc('pw_import_history');
      final oldHistory = (await tx.get(historyDoc)).data()?['value'];
      final history = oldHistory is List ? [...oldHistory] : <dynamic>[];
      var added = 0, skipped = 0;
      final conflicts = <String>[];
      for (final k in kinds) {
        final value = values[k]!;
        final selected = rows.where((r) => r.storageKey == k);
        final result = k == 'pw_lectures_tree'
            ? mergeLectureRows(
                value,
                selected,
                () => legacyUid('app'),
                batchId: batchId,
              )
            : mergeRows(
                value,
                selected,
                () => legacyUid('app'),
                batchId: batchId,
              );
        added += result.added;
        skipped += result.skipped;
        conflicts.addAll(result.conflicts);
        if (result.added > 0) {
          _checkSize(value);
          tx.set(docs[k]!, {
            'value': value,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          }, SetOptions(merge: true));
        }
      }
      history.insert(0, {
        'id': batchId,
        'status': 'active',
        'touched': kinds,
        'source': 'hyzen_android',
        'files': names,
        'rows': rows.length,
        'added': added,
        'skipped': skipped,
        'conflicts': conflicts,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      tx.set(historyDoc, {
        'value': history.take(80).toList(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      return MergeResult(added, skipped, conflicts);
    });
  }

  Future<int> undoImport(String id) async {
    _guard();
    return _db.runTransaction((tx) async {
      _guard();
      final historyRef = _doc('pw_import_history');
      final history = _importMaps((await tx.get(historyRef)).data()?['value']);
      final item = history.where((m) => m['id'] == id).firstOrNull;
      if (item == null || item['status'] == 'undone') {
        throw FriendlyException(
          'This import is already undone or unavailable.',
        );
      }
      final touched = (item['touched'] as List? ?? [])
          .whereType<String>()
          .map(
            (key) => switch (key) {
              'notes' => 'pw_notes_tree',
              'special' => 'pw_special_tree',
              'mcqs' => 'pw_mcqs_tree',
              'papers' => 'pw_pastpapers',
              'lectures' => 'pw_lectures_tree',
              _ => key,
            },
          )
          .toList();
      if (touched.isEmpty || touched.any((k) => !writableKeys.contains(k))) {
        throw FriendlyException('This older import has no undo record.');
      }
      final trees = <String, List<Map<String, dynamic>>>{};
      for (final key in touched) {
        trees[key] = _importMaps((await tx.get(_doc(key))).data()?['value']);
      }
      var removed = 0;
      for (final entry in trees.entries) {
        removed += undoImportNodes(entry.value, id);
        tx.set(_doc(entry.key), {
          'value': entry.value,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
      }
      item['status'] = 'undone';
      item['undoneAt'] = DateTime.now().toUtc().toIso8601String();
      tx.set(historyRef, {
        'value': history,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      return removed;
    });
  }
}

void setPath(Map<String, dynamic> map, String path, Object? value) {
  final keys = path.split('.');
  var current = map;
  for (final key in keys.take(keys.length - 1)) {
    final next = Map<String, dynamic>.from(
      current[key] is Map ? current[key] : {},
    );
    current[key] = next;
    current = next;
  }
  current[keys.last] = value;
}

Object? getPath(Map<String, dynamic> map, String path) {
  Object? current = map;
  for (final key in path.split('.')) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

Map<String, dynamic> publicOrder(Map<String, dynamic> o) => {
  'orderNumber': o['orderNumber'],
  'status': o['status'],
  'payment': o['payment'],
  'createdAt': o['createdAt'],
  'trackingId': o['trackingId'] ?? '',
  'totals': {'grandTotal': (o['totals'] as Map?)?['grandTotal'] ?? 0},
  'items': (o['items'] as List? ?? [])
      .whereType<Map>()
      .map((i) => {'name': i['name'], 'qty': i['qty'], 'price': i['price']})
      .toList(),
  'customer': {
    for (final key in ['firstName', 'lastName', 'phone'])
      key: (o['customer'] as Map?)?[key] ?? '',
  },
  'address': {
    for (final key in ['city', 'province'])
      key: (o['address'] as Map?)?[key] ?? '',
  },
};
int mergeOrderInbox(
  List<Map<String, dynamic>> orders,
  List<Map<String, dynamic>> products,
  List<Map<String, dynamic>> inbox,
) {
  var added = 0;
  for (final raw in inbox) {
    if (orders.any((o) => o['id'] == raw['id'])) continue;
    final o = Map<String, dynamic>.from(raw);
    if (o['stockApplied'] != true) {
      for (final item in (o['items'] as List? ?? []).whereType<Map>()) {
        final product = products
            .where((p) => p['id'] == item['productId'])
            .firstOrNull;
        if (product == null ||
            product['stockCount'] == null ||
            product['stockCount'] == '') {
          continue;
        }
        final before = int.tryParse('${product['stockCount']}') ?? 0,
            qty = int.tryParse('${item['qty']}') ?? 0;
        if (qty <= 0) continue;
        final count = (before - qty).clamp(0, 2147483647);
        product['stockCount'] = count;
        if (count == 0) {
          product['stockStatus'] = 'out_of_stock';
        } else if (count <= 5) {
          product['stockStatus'] = 'low_stock';
        }
      }
      o['stockApplied'] = true;
    }
    orders.add(o);
    added++;
  }
  return added;
}

final adminValueProvider = StreamProvider.autoDispose.family<Object?, String>((
  ref,
  key,
) {
  if (!ref.watch(isAdminProvider)) return Stream.value(null);
  return ref.watch(adminRepositoryProvider).watch(key);
});

List<Map<String, dynamic>> _importMaps(Object? raw) => raw is List
    ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];

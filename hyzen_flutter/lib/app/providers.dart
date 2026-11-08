import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/backend.dart';
import '../core/storage/local_store.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/student_profile.dart';

/// Overridden in bootstrap with real instances.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);
final firebaseReadyProvider = Provider<bool>((_) => false);

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (_) => FirebaseAuth.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);
final profileRepositoryProvider = Provider<StudentProfileRepository>(
  (ref) => StudentProfileRepository(ref.watch(firestoreProvider)),
);
final pendingProfileStoreProvider = Provider<PendingProfileStore>(
  (ref) => PendingProfileStore(ref.watch(sharedPrefsProvider)),
);

final authStateProvider = StreamProvider<User?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return Stream.value(null);
  return ref.watch(authRepositoryProvider).authChanges();
});

/// CONFIRMED legacy rule: admin == Firebase user whose uid == PW_ADMIN_UID.
final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid == Backend.adminUid,
);

/// Local profile is available immediately and survives successful sync/relaunch.
final profileProvider = StreamProvider<StudentProfile?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.uid == Backend.adminUid) return Stream.value(null);
  final store = ref.watch(pendingProfileStoreProvider);
  final repo = ref.watch(profileRepositoryProvider);
  final controller = StreamController<StudentProfile?>();
  final cached = store.cached(user.uid);
  StudentProfile? local = cached == null
      ? null
      : StudentProfile.fromMap(user.uid, cached);
  controller.add(local);
  bool syncing = false, disposed = false;
  Future<void> sync() async {
    if (syncing || disposed) return;
    final draft = store.read(user.uid);
    if (draft == null) return;
    syncing = true;
    try {
      await repo.create(StudentProfile.fromMap(user.uid, draft));
      // A newer edit may have arrived while the request was in flight.
      if (jsonEncode(store.read(user.uid)) == jsonEncode(draft)) {
        await store.clear(user.uid);
      }
    } catch (_) {
    } finally {
      syncing = false;
    }
  }

  unawaited(sync());
  final timer = Timer.periodic(const Duration(seconds: 45), (_) => sync());
  final sub = repo
      .watch(user.uid)
      .listen(
        (remote) {
          if (disposed) return;
          final pending = store.read(user.uid);
          if (pending != null) {
            local = StudentProfile.fromMap(user.uid, pending);
          } else if (remote != null) {
            local = remote;
            unawaited(store.cache(user.uid, remote.toWriteMap()));
          }
          controller.add(local);
        },
        onError: (_) {
          if (!disposed) controller.add(local);
        },
      );
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    unawaited(sub.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

final professionalYearProvider = Provider<int?>(
  (ref) => ref.watch(profileProvider).valueOrNull?.professionalYear,
);

// ---------- Preferences ----------
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _k = 'theme_mode';
  @override
  ThemeMode build() {
    final v = ref.watch(sharedPrefsProvider).getString(_k);
    return ThemeMode.values.firstWhere(
      (m) => m.name == v,
      orElse: () => ThemeMode.light,
    );
  }

  void set(ThemeMode m) {
    state = m;
    ref.read(sharedPrefsProvider).setString(_k, m.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class BoolPref extends FamilyNotifier<bool, String> {
  @override
  bool build(String key) =>
      ref.watch(sharedPrefsProvider).getBool(key) ?? _defaults[key] ?? false;
  static const _defaults = {
    'pref_wifi_only': false,
    'pref_announcements': true,
  };
  void set(bool v) {
    state = v;
    ref.read(sharedPrefsProvider).setBool(arg, v);
  }
}

final boolPrefProvider = NotifierProvider.family<BoolPref, bool, String>(
  BoolPref.new,
);

/// Convenience to keep `unawaited` import used in features.
void fireAndForget(Future<void> f) => unawaited(f);

class TextSizeNotifier extends Notifier<int> {
  static const sizes = [
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
  ];
  @override
  int build() {
    final value = ref.watch(sharedPrefsProvider).getInt('app_text_size');
    return sizes.contains(value) ? value! : 13;
  }

  Future<void> set(int value) async {
    if (!sizes.contains(value)) return;
    await ref.read(sharedPrefsProvider).setInt('app_text_size', value);
    state = value;
  }
}

final textSizeProvider = NotifierProvider<TextSizeNotifier, int>(
  TextSizeNotifier.new,
);

/// Changes only when the user explicitly closes the app or starts a new session.
final sessionRevisionProvider = StateProvider<int>((ref) => 0);

final searchRevisionProvider = StateProvider<int>((ref) => 0);

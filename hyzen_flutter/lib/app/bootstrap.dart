import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/firebase/firebase_options.dart';
import '../core/storage/local_store.dart';
import 'app.dart';
import '../features/study_progress/study_notifications.dart';
import 'providers.dart';

/// Initialise only what the first frame needs. No artificial delay.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase, preferences and Hive are independent: start them together so
  // cold start waits for the slowest one instead of the sum of all three.
  Future<bool> firebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Firebase init failed: $e');
      return false;
    }
  }

  final results = await Future.wait<Object?>([
    firebase(),
    SharedPreferences.getInstance(),
    Boxes.init(),
  ]);
  unawaited(StudyNotificationScheduler.instance.initialize());
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(results[1] as SharedPreferences),
        firebaseReadyProvider.overrideWithValue(results[0] as bool),
      ],
      child: const HyzenApp(),
    ),
  );
}

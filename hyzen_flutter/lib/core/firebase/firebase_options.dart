// Firebase options for the EXISTING Hyzen project (pharmawhisper-debd2).
// CONFIRMED sources:
//  - web: PharmD_with_Hyzen_Web_App_Ready_v2.html (window.PW_FIREBASE_CONFIG)
//  - android: android/app/google-services.json supplied by the owner (com.hyzen.pharmd)
// These are public client identifiers (not secrets). Security is enforced by
// Firestore rules + Firebase Auth. Never place Admin SDK / service-account keys here.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        // iOS not registered yet in the existing project. Fall back to web
        // identifiers is NOT valid for native iOS; register an iOS app first.
        throw UnsupportedError(
          'This platform is not supported yet.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCYhq5MsI2DHSLeqIoRe-pSRZ4TJOUxdME',
    appId: '1:975548206224:web:97abc2ce711b5de8d95c15',
    messagingSenderId: '975548206224',
    projectId: 'pharmawhisper-debd2',
    authDomain: 'pharmawhisper-debd2.firebaseapp.com',
    storageBucket: 'pharmawhisper-debd2.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDrgo_nczpplCBRgeHk4oNCKLoStEdMV0g',
    appId: '1:975548206224:android:4d1d78ad7f7e5b8cd95c15',
    messagingSenderId: '975548206224',
    projectId: 'pharmawhisper-debd2',
    storageBucket: 'pharmawhisper-debd2.firebasestorage.app',
  );
}

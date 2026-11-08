import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

const hyzenOneSignalAppId = 'c8344ed8-429a-4c09-8f74-6cc120918dda';

/// onesignal:managed v1 — all SDK calls stay in this Android-only adapter.
class PushService {
  PushService._();
  static final instance = PushService._();
  bool initialized = false;
  String? uid;
  String? _desiredUid;
  bool _identityBound = false;
  String? identityError;
  final subscriptionState = ValueNotifier<String>(
    'Push unavailable on this platform',
  );
  bool _loggedSubscription = false;
  Future<void> _identity = Future.value();
  final events = StreamController<Map<String, dynamic>>.broadcast();
  final pending = <Map<String, dynamic>>[];
  void initialize() {
    if (initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    initialized = true;
    OneSignal.initialize(hyzenOneSignalAppId);
    OneSignal.User.pushSubscription.addObserver((_) => _updateSubscription());
    _updateSubscription();
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      _receive(event.notification, false);
    });
    OneSignal.Notifications.addClickListener(
      (event) => _receive(event.notification, true),
    );
  }

  void _updateSubscription() {
    if (identityError != null) {
      subscriptionState.value = identityError!;
      return;
    }
    final id = OneSignal.User.pushSubscription.id;
    final registered = id != null && id.isNotEmpty && !id.startsWith('local-');
    subscriptionState.value = !registered
        ? 'Waiting for device registration'
        : OneSignal.User.pushSubscription.optedIn == true
        ? 'Device registered · push enabled'
        : 'Device registered · push disabled';
    if (kDebugMode && registered && !_loggedSubscription) {
      _loggedSubscription = true;
      debugPrint('Hyzen OneSignal test subscription: $id');
    }
  }

  void _receive(OSNotification notification, bool opened) {
    final data = notification.additionalData ?? {};
    final target = data['recipientUid'];
    if (target != null && target != uid) return;
    final item = <String, dynamic>{
      'id': 'push_${data['messageId'] ?? notification.notificationId}',
      'title': notification.title ?? 'Hyzen',
      'body': notification.body ?? '',
      'url': safePushRoute(data['route']),
      'opened': opened,
      'owner': uid,
      'needsVerification': true,
    };
    if (!events.hasListener) {
      pending.add(item);
    } else {
      events.add(item);
    }
  }

  Future<void> identify(String? next) {
    _desiredUid = next;
    if (!initialized) return Future.value();
    _identity = _identity
        .catchError((Object _) {})
        .then((_) async {
          if (_identityBound && uid == next && identityError == null) return;
          await OneSignal.logout();
          uid = null;
          if (next != null) await OneSignal.login(next);
          uid = next;
          _identityBound = true;
          identityError = null;
          _updateSubscription();
        })
        .catchError((Object _) {
          uid = null;
          _identityBound = false;
          identityError =
              'Push identity update failed. Enable push again to retry.';
          subscriptionState.value = identityError!;
        });
    return _identity;
  }

  Future<bool> enable(bool on) async {
    if (!initialized) return false;
    if (identityError != null) {
      await identify(_desiredUid);
      if (identityError != null) return false;
    }
    try {
      if (!on) {
        await OneSignal.User.pushSubscription.optOut();
        return false;
      }
      final allowed = await OneSignal.Notifications.requestPermission(true);
      if (allowed) await OneSignal.User.pushSubscription.optIn();
      return allowed;
    } catch (_) {
      subscriptionState.value =
          'Push preference could not be saved. Try again.';
      return false;
    }
  }

  String? get subscriptionId =>
      initialized ? OneSignal.User.pushSubscription.id : null;
}

String safePushRoute(Object? value) {
  final route = value?.toString() ?? '';
  const allowed = [
    '/home',
    '/study',
    '/downloads',
    '/pdf-studio',
    '/study-goals',
    '/study-streak',
    '/campus-rank',
    '/notifications',
  ];
  return allowed.contains(route) ? route : '/notifications';
}

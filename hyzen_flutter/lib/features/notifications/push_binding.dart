import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import 'notifications_screen.dart';
import 'push_service.dart';
import 'push_api.dart';
import 'push_click_store.dart';

class PushBinding extends ConsumerStatefulWidget {
  const PushBinding({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PushBinding> createState() => _PushBindingState();
}

class _PushBindingState extends ConsumerState<PushBinding>
    with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? subscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = PushService.instance.events.stream.listen(
      (item) => unawaited(receive(item)),
    );
    ref.listenManual(authStateProvider, (_, next) async {
      if (next.isLoading) return;
      await PushService.instance.identify(next.valueOrNull?.uid);
      if (!mounted || next.valueOrNull == null) return;
      final buffered = [...PushService.instance.pending];
      PushService.instance.pending.clear();
      for (final item in buffered) {
        unawaited(receive(item));
      }
      await syncInbox();
    }, fireImmediately: true);
  }

  Future<void> receive(Map<String, dynamic> item) async {
    if (!mounted) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final clickId = item['opened'] == true ? item['id']?.toString() : null;
    if (clickId != null &&
        item['needsVerification'] == true &&
        (item['owner'] == null || item['owner'] == uid)) {
      await PushClickStore(
        ref.read(sharedPrefsProvider),
      ).remember(uid ?? '', clickId);
      if (!mounted || ref.read(authStateProvider).valueOrNull?.uid != uid) {
        return;
      }
    }
    if (uid == null) {
      PushService.instance.pending.add(item);
      return;
    }
    if (item['owner'] != null && item['owner'] != uid) return;
    if (item['needsVerification'] == true) {
      // An old account's OS notification can arrive after account switching.
      // Only this Firebase user's authenticated server inbox authorizes insertion
      // and navigation. Never infer audience membership from the current SDK UID.
      for (var attempt = 0; attempt < 3; attempt++) {
        if (await syncInbox(
          openedId: clickId,
          expectedId: item['id']?.toString(),
        )) {
          return;
        }
        if (!mounted || ref.read(authStateProvider).valueOrNull?.uid != uid) {
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
      return;
    }
    ref.read(notificationsProvider.notifier).receivePush(item);
    if (item['opened'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(authStateProvider).valueOrNull?.uid == uid) {
          ref.read(routerProvider).go(safePushRoute(item['url']));
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncInbox().then((_) {}));
  }

  Future<bool> syncInbox({String? openedId, String? expectedId}) async {
    if (!mounted) return false;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || pushApiBase.isEmpty) return false;
    final clicks = PushClickStore(ref.read(sharedPrefsProvider));
    final requestedId = expectedId;
    openedId ??= clicks.pending(user.uid) ?? clicks.pending('');
    expectedId ??= openedId;
    try {
      final path = requestedId == null
          ? '/inbox'
          : '/inbox/${Uri.encodeComponent(requestedId.replaceFirst('push_', ''))}';
      final inbox = await PushApi.call(user, path);
      final rows = List<dynamic>.from(inbox['items'] as List? ?? []);
      if (requestedId == null &&
          openedId != null &&
          !rows.any((row) => 'push_${row['id']}' == openedId)) {
        final older = await PushApi.call(
          user,
          '/inbox/${Uri.encodeComponent(openedId.replaceFirst('push_', ''))}',
        );
        rows.addAll(older['items'] as List? ?? []);
      }
      if (!mounted ||
          ref.read(authStateProvider).valueOrNull?.uid != user.uid) {
        return false;
      }
      for (final row in rows) {
        await receive({
          'id': 'push_${row['id']}',
          'title': row['title'],
          'body': row['body'],
          'url': safePushRoute(row['route']),
          'owner': user.uid,
          'opened':
              openedId == 'push_${row['id']}' &&
              (clicks.pending(user.uid) ?? clicks.pending('')) == openedId,
        });
        if (openedId == 'push_${row['id']}') {
          final confirmedId = 'push_${row['id']}';
          await clicks.forget(user.uid, confirmedId);
          await clicks.forget('', confirmedId);
        }
      }
      return expectedId == null ||
          rows.any((row) => 'push_${row['id']}' == expectedId);
    } catch (_) {
      /* Local inbox is retained during connectivity loss. */
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

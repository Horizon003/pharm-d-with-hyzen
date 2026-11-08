import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../notifications/push_api.dart';
import '../../notifications/push_service.dart';
import '../../study_progress/study_session.dart';

class PushCenter extends ConsumerStatefulWidget {
  const PushCenter({super.key});
  @override
  ConsumerState<PushCenter> createState() => _PushCenterState();
}

class _PushCenterState extends ConsumerState<PushCenter> {
  final title = TextEditingController(), body = TextEditingController();
  String target = 'all', category = 'announcement', route = '/notifications';
  String? college, error, result;
  int year = 1;
  bool busy = false;
  List<String> colleges = [];
  List<Map<String, dynamic>> history = [];
  String? attemptId, attemptContent;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || !ref.read(isAdminProvider)) return;
    try {
      final audiences = await PushApi.call(user, '/audiences');
      final sent = await PushApi.call(user, '/history');
      if (mounted) {
        setState(() {
          colleges = (audiences['colleges'] as List).cast<String>();
          history = (sent['results'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> send() async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      setState(() => error = 'Enter a title and message.');
      return;
    }
    if (target == 'college' && college == null) {
      setState(() => error = 'Select a verified college.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title.text),
        content: Text(
          '${body.text}\n\nAudience: $target${target == 'professional'
              ? ' · Prof $year'
              : target == 'college'
              ? ' · $college'
              : ''}\nDestination: $route',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send notification'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final content =
        '${title.text}|${body.text}|$target|$college|$year|$route|$category';
    if (content != attemptContent) {
      final hex = studyId();
      attemptId =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-8${hex.substring(17, 20)}-${hex.substring(20)}';
      attemptContent = content;
    }
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final response = await PushApi.call(
        ref.read(authStateProvider).valueOrNull!,
        '/send',
        body: {
          'id': attemptId,
          'title': title.text,
          'body': body.text,
          'target': target,
          'college': college,
          'year': year,
          'route': route,
          'category': category,
        },
      );
      if (mounted) {
        setState(
          () => result =
              'Accepted by OneSignal: ${response['id']}. Device delivery has not yet been confirmed.',
        );
      }
      await load();
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              '$e\nRetry uses the same message ID to prevent duplicate sends.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(isAdminProvider)) {
      return const Scaffold(
        body: Center(child: Text('Administrator access required')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notification Center'),
        actions: [
          IconButton(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Send public study announcements only. Do not include private student '
            'details, health information or confidential messages in push alerts.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: title,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: body,
            maxLength: 1000,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Notification type'),
            items: [
              for (final v in [
                'announcement',
                'material',
                'rank',
                'update',
                'task',
              ])
                DropdownMenuItem(value: v, child: Text(v)),
            ],
            onChanged: (v) => setState(() => category = v!),
          ),
          DropdownButtonFormField<String>(
            initialValue: target,
            decoration: const InputDecoration(labelText: 'Recipients'),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All verified students'),
              ),
              DropdownMenuItem(
                value: 'college',
                child: Text('Specific college'),
              ),
              DropdownMenuItem(
                value: 'professional',
                child: Text('Specific professional year'),
              ),
            ],
            onChanged: (v) => setState(() => target = v!),
          ),
          if (target == 'professional')
            DropdownButtonFormField<int>(
              initialValue: year,
              items: [
                for (var v = 1; v <= 5; v++)
                  DropdownMenuItem(value: v, child: Text('Professional $v')),
              ],
              onChanged: (v) => setState(() => year = v!),
            ),
          if (target == 'college')
            DropdownButtonFormField<String>(
              initialValue: college,
              decoration: const InputDecoration(labelText: 'Verified college'),
              items: [
                for (final v in colleges)
                  DropdownMenuItem(value: v, child: Text(v)),
              ],
              onChanged: (v) => setState(() => college = v),
            ),
          DropdownButtonFormField<String>(
            initialValue: route,
            decoration: const InputDecoration(labelText: 'Open screen'),
            items: [
              for (final v in [
                '/home',
                '/study',
                '/downloads',
                '/pdf-studio',
                '/study-goals',
                '/study-streak',
                '/campus-rank',
                '/notifications',
              ])
                DropdownMenuItem(value: v, child: Text(safePushRoute(v))),
            ],
            onChanged: (v) => setState(() => route = v!),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : send,
            icon: const Icon(Icons.send_outlined),
            label: Text(busy ? 'Sending…' : 'Preview and send'),
          ),
          if (error != null) SelectableText(error!),
          if (result != null) SelectableText(result!),
          const Divider(height: 32),
          const Text('Send history'),
          for (final item in history)
            ListTile(
              title: Text(item['title'] ?? ''),
              subtitle: Text('${item['state']} · ${item['created_at']}'),
              trailing: IconButton(
                tooltip: 'Check provider status',
                icon: const Icon(Icons.info_outline),
                onPressed: () async {
                  try {
                    final status = await PushApi.call(
                      ref.read(authStateProvider).valueOrNull!,
                      '/status/${item['id']}',
                    );
                    if (context.mounted) {
                      showDialog<void>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('OneSignal status'),
                          content: Text(
                            '$status\nDispatched counts are not proof that the phone displayed the alert.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) setState(() => error = e.toString());
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

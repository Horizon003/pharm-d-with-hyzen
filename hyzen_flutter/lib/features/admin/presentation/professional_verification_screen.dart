import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/common.dart';
import '../data/admin_repository.dart';
import 'admin_management.dart' show adminAction;

class ProfessionalVerificationScreen extends ConsumerStatefulWidget {
  const ProfessionalVerificationScreen({super.key});
  @override
  ConsumerState<ProfessionalVerificationScreen> createState() =>
      _VerificationState();
}

class _VerificationState extends ConsumerState<ProfessionalVerificationScreen> {
  final uid = TextEditingController();
  int year = 1;
  bool verified = true, busy = false;
  @override
  void dispose() {
    uid.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    await adminAction(
      context,
      ref,
      () => ref
          .read(adminRepositoryProvider)
          .setProfessionalVerification(uid.text.trim(), year, verified),
      message: 'Professional verification saved',
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(firebaseReadyProvider)) {
      return const Scaffold(
        appBar: HTopBar(title: 'Professional verification'),
        body: Center(
          child: Text('Connect your account to manage professional years.'),
        ),
      );
    }
    final repo = ref.watch(adminRepositoryProvider);
    return Scaffold(
      appBar: const HTopBar(title: 'Professional verification'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Verify the student’s professional year after checking their record. Students choose their own ranking consent and alias.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: uid,
            decoration: const InputDecoration(
              labelText: 'Student account ID',
              helperText: 'Copy the exact UID from the student’s account.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: year,
            key: ValueKey(year),
            decoration: const InputDecoration(labelText: 'Professional year'),
            items: [
              for (var i = 1; i <= 5; i++)
                DropdownMenuItem(value: i, child: Text('Year $i')),
            ],
            onChanged: busy ? null : (v) => setState(() => year = v ?? 1),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Record verified'),
            value: verified,
            onChanged: busy ? null : (v) => setState(() => verified = v),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving…' : 'Save verification'),
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: repo.professionalMemberships(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Could not read verification records. Check administrator access.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  for (final m in snapshot.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${m['alias'] ?? 'Student'} · Year ${m['academicYear']}',
                      ),
                      subtitle: Text(
                        '${m['uid']}\n${m['verified'] == true
                            ? 'Verified'
                            : m['verificationRequestedAt'] != null
                            ? 'Review requested · Year ${m['requestedYear'] ?? m['academicYear']}'
                            : 'Not verified'}',
                      ),
                      isThreeLine: true,
                      onTap: () => setState(() {
                        uid.text = '${m['uid']}';
                        year =
                            (m['requestedYear'] as num? ??
                                    m['academicYear'] as num?)
                                ?.toInt() ??
                            1;
                        verified = m['verified'] == true;
                      }),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

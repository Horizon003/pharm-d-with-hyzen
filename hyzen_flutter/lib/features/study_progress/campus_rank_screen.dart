import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../home/presentation/home_time_artwork.dart';

const _navy = Color(0xFF091C43);
const _blue = Color(0xFF1B66B2);

class CampusEntry {
  const CampusEntry(this.rank, this.name, this.year, this.minutes, this.points,
      this.uid);
  final int rank, year, minutes, points;
  final String name, uid;
  factory CampusEntry.fromMap(Map<String, dynamic> d) => CampusEntry(
    (d['rank'] as num?)?.toInt() ?? 0,
    (d['alias'] ?? 'Student').toString(),
    (d['academicYear'] as num?)?.toInt() ?? 0,
    (d['verifiedMinutes'] as num?)?.toInt() ?? 0,
    (d['score'] as num?)?.toInt() ?? 0,
    (d['uid'] ?? '').toString());
}

class CampusBoard {
  const CampusBoard(this.status, this.entries, this.mine, this.updatedAt);
  final String status;
  final List<CampusEntry> entries;
  final CampusEntry? mine;
  final DateTime? updatedAt;
}

/// Read only from server-computed, verified public leaderboard snapshots.
/// Never calculate a fake competitive rank from local browser data.
final campusBoardProvider = FutureProvider.family<CampusBoard, String>((ref, period) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const CampusBoard('Sign in to view campus rankings.', [], null, null);
  final firestore = ref.watch(firestoreProvider);
  try {
    final account = await firestore.collection('students').doc(user.uid).get();
    final profile = account.data();
    if (profile == null || profile['campusVerified'] != true ||
        (profile['campusId'] ?? '').toString().isEmpty) {
      return const CampusBoard('Campus verification is required before rankings are available.', [], null, null);
    }
    final campusId = profile['campusId'].toString();
    final periodRef = firestore.collection('campusLeaderboards')
      .doc(campusId).collection('periods').doc(period);
    final meta = await periodRef.get();
    if (!meta.exists) {
      return const CampusBoard('No verified leaderboard has been published for this period.', [], null, null);
    }
    final snapshot = await periodRef.collection('entries')
      .orderBy('rank').limit(30).get();
    final entries = snapshot.docs.map((d) => CampusEntry.fromMap(d.data()))
      .where((e) => e.rank > 0 && e.uid.isNotEmpty).toList();
    final mineDoc = await periodRef.collection('entries').doc(user.uid).get();
    final mine = mineDoc.exists ? CampusEntry.fromMap(mineDoc.data()!) : null;
    final updatedAt = meta.data()?['updatedAt'];
    return CampusBoard('ready', entries, mine,
      updatedAt is Timestamp ? updatedAt.toDate() : null);
  } catch (_) {
    return const CampusBoard('Rankings are unavailable or you do not have permission to view them.', [], null, null);
  }
});

class CampusRankScreen extends ConsumerStatefulWidget {
  const CampusRankScreen({super.key});
  @override
  ConsumerState<CampusRankScreen> createState() => _CampusRankScreenState();
}

class _CampusRankScreenState extends ConsumerState<CampusRankScreen> {
  var period = 'week';
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : _navy;
    final bg = dark ? Colors.black : const Color(0xFFEAF3FF);
    final surface = dark ? const Color(0xFF1B1C20) : Colors.white;
    final profile = ref.watch(profileProvider).valueOrNull;
    final board = ref.watch(campusBoardProvider(period));
    Widget panel(Widget content) => Container(
      width: double.infinity, padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(22),
        border: Border.all(color: dark ? Colors.white12 : const Color(0xFFD3E2F3))),
      child: content);

    return Scaffold(backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, centerTitle: true,
        title: Column(children: [
          Text('🏆 Campus Rank', style: TextStyle(color: ink,
              fontWeight: FontWeight.w900, fontSize: 22)),
          Text('Top learners from your campus',
            style: TextStyle(color: ink.withValues(alpha: .67), fontSize: 11)),
        ]),
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: ink),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
        actions: [IconButton(icon: Icon(Icons.info_outline_rounded, color: ink),
          onPressed: () => _showRules(context))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 32), children: [
        Container(height: 135, clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
          child: Stack(children: [
            Positioned.fill(child: Image.asset(
              HomeTimePhase.at(DateTime.now()).asset, fit: BoxFit.cover)),
            const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xC7F0F6FF), Color(0x00FFFFFF)])))),
            Positioned(left: 16, bottom: 16, right: 16, child: Align(
              alignment: Alignment.bottomLeft, child: Material(
                color: const Color(0xEDFFFFFF),
                borderRadius: BorderRadius.circular(22), child: Padding(
                  padding: const EdgeInsets.all(11), child: Row(
                    mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.school_outlined, color: _blue),
                      const SizedBox(width: 8),
                      Flexible(child: Text(profile?.institutionName.isNotEmpty == true
                        ? profile!.institutionName : 'Your campus',
                        maxLines: 2, style: const TextStyle(color: _navy,
                          fontWeight: FontWeight.w800, fontSize: 12))),
                    ]))),
              )),
          ])),
        const SizedBox(height: 14),
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'week', label: Text('This Week')),
          ButtonSegment(value: 'month', label: Text('This Month')),
          ButtonSegment(value: 'semester', label: Text('This Semester')),
        ], selected: {period}, showSelectedIcon: false,
          onSelectionChanged: (values) => setState(() => period = values.first)),
        const SizedBox(height: 16),
        board.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(35),
            child: CircularProgressIndicator())),
          error: (e, _) => panel(Text('Could not load verified rankings: $e')),
          data: (data) => Column(children: [
            panel(Column(children: [
              Row(children: [Icon(Icons.account_circle, color: _blue),
                const SizedBox(width: 7),
                Text('Your Rank', style: TextStyle(color: ink, fontWeight: FontWeight.w700))]),
              const SizedBox(height: 10),
              if (data.mine == null)
                Text(data.status == 'ready' ? 'Not ranked this period' : data.status,
                  textAlign: TextAlign.center, style: TextStyle(color: ink))
              else
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _RankStat('#${data.mine!.rank}', 'Your rank', ink),
                  _RankStat('${data.mine!.minutes ~/ 60}h ${data.mine!.minutes % 60}m',
                    'Verified study', ink),
                  _RankStat('${data.mine!.points}', 'Points', ink),
                ]),
            ])),
            const SizedBox(height: 14),
            panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.emoji_events_outlined, color: Color(0xFFE3B52A)),
                const SizedBox(width: 8),
                Expanded(child: Text('Leaderboard', style: TextStyle(color: ink,
                  fontWeight: FontWeight.w900, fontSize: 18))),
                IconButton(icon: Icon(Icons.refresh_rounded, color: ink),
                  onPressed: () => ref.invalidate(campusBoardProvider(period))),
              ]),
              if (data.updatedAt != null)
                Text('Last verified update: ${data.updatedAt!.toLocal()}',
                  style: TextStyle(color: ink.withValues(alpha: .55), fontSize: 10)),
              if (data.entries.isEmpty)
                Padding(padding: const EdgeInsets.all(18), child: Text(data.status,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ink.withValues(alpha: .7))))
              else for (final entry in data.entries)
                Padding(padding: const EdgeInsets.only(top: 8),
                  child: _RankRow(entry: entry,
                    highlight: entry.uid == ref.read(authStateProvider).valueOrNull?.uid,
                    ink: ink, dark: dark)),
              if (data.mine != null && !data.entries.any((e) => e.uid == data.mine!.uid))
                Padding(padding: const EdgeInsets.only(top: 12),
                  child: _RankRow(entry: data.mine!, highlight: true,
                    ink: ink, dark: dark)),
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        panel(ListTile(contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bar_chart_rounded, color: _blue),
          title: Text('How Campus Rank Works?',
            style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
          subtitle: Text('Only verified active study and eligible students count.',
            style: TextStyle(fontSize: 11, color: ink.withValues(alpha: .6))),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _showRules(context))),
      ]),
    );
  }

  Future<void> _showRules(BuildContext context) => showDialog<void>(
    context: context, builder: (dialog) => AlertDialog(
      title: const Text('How Campus Rank Works'),
      content: const SingleChildScrollView(child: Text(
        'Ranks must be generated by the verified campus backend from active study sessions, not from editable local time.\n\n'
        'Proposed scoring: 1 point per verified minute (max 360 minutes per day), '
        '+2 points per valid 10-minute session (max 5 sessions per day), '
        'and +5 for each consecutive qualifying day after the first.\n\n'
        'Your school must verify membership and students must be able to opt out. '
        'Until this backend is deployed and verified, no fake rankings are shown.')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog),
        child: const Text('Close'))],
    ),
  );
}

class _RankStat extends StatelessWidget {
  const _RankStat(this.value, this.label, this.ink);
  final String value, label;
  final Color ink;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: ink, fontWeight: FontWeight.w900,
      fontSize: 17)),
    Text(label, style: TextStyle(color: ink.withValues(alpha: .6), fontSize: 10)),
  ]);
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.highlight,
    required this.ink, required this.dark});
  final CampusEntry entry;
  final bool highlight, dark;
  final Color ink;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: highlight ? (dark ? const Color(0xFF13355C) :
          const Color(0xFFD1E7FF)) : (dark ? Colors.white10 :
          const Color(0xFFF4F7FE)),
      borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      SizedBox(width: 25, child: Text('#${entry.rank}',
        style: TextStyle(color: ink, fontWeight: FontWeight.w900))),
      const CircleAvatar(radius: 18, child: Icon(Icons.person_outline, size: 20)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(entry.name, style: TextStyle(color: ink,
          fontWeight: FontWeight.w800), maxLines: 1,
            overflow: TextOverflow.ellipsis),
          Text('Year ${entry.year}', style: TextStyle(
            color: ink.withValues(alpha: .6), fontSize: 10))])),
      Text('${entry.minutes ~/ 60}h ${entry.minutes % 60}m',
        style: TextStyle(color: ink, fontSize: 11)),
      const SizedBox(width: 6),
      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(11)),
        child: Text('${entry.points} pts', style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
    ]),
  );
}

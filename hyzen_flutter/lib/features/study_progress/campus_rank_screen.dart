import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_cloud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../home/presentation/home_time_artwork.dart';

const _navy = Color(0xFF091C43);
const _blue = Color(0xFF1B66B2);

class CampusEntry {
  const CampusEntry(
    this.rank,
    this.name,
    this.year,
    this.minutes,
    this.points,
    this.uid,
  );
  final int rank, year, minutes, points;
  final String name, uid;
  Map<String, dynamic> toJson() => {
    'rank': rank,
    'alias': name,
    'academicYear': year,
    'verifiedMinutes': minutes,
    'score': points,
    'uid': uid,
  };
  factory CampusEntry.fromMap(Map<String, dynamic> d) => CampusEntry(
    (d['rank'] as num?)?.toInt() ?? 0,
    (d['alias'] ?? 'Student').toString(),
    (d['academicYear'] as num?)?.toInt() ?? 0,
    (d['verifiedMinutes'] as num?)?.toInt() ?? 0,
    (d['score'] as num?)?.toInt() ?? 0,
    (d['uid'] ?? '').toString(),
  );
}

class CampusBoard {
  const CampusBoard(
    this.status,
    this.entries,
    this.mine,
    this.updatedAt, {
    this.next,
    this.generation,
    this.cached = false,
    this.academicYear,
  });
  final String status;
  final List<CampusEntry> entries;
  final CampusEntry? mine;
  final DateTime? updatedAt;
  final int? next;
  final String? generation;
  final bool cached;
  final int? academicYear;
}

class CampusController extends StateNotifier<AsyncValue<CampusBoard>> {
  CampusController(this.cloud, this.prefs, this.key, this.period)
    : super(const AsyncLoading()) {
    if (cloud == null) {
      state = const AsyncData(
        CampusBoard(
          'Verified Professional Rank is not connected yet.',
          [],
          null,
          null,
        ),
      );
    } else {
      unawaited(load());
    }
  }
  final StudyCloud? cloud;
  final SharedPreferences prefs;
  final String key, period;
  bool loading = false;
  CampusBoard decode(Map<String, dynamic> data, {bool cached = false}) =>
      CampusBoard(
        data['status'] ?? 'ready',
        (data['entries'] as List? ?? [])
            .map((e) => CampusEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        data['mine'] == null
            ? null
            : CampusEntry.fromMap(Map<String, dynamic>.from(data['mine'])),
        data['updatedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(data['updatedAt']),
        next: data['next'],
        generation: data['generation'],
        cached: cached,
        academicYear: (data['academicYear'] as num?)?.toInt(),
      );
  Future<void> load({bool more = false}) async {
    if (loading || cloud == null) return;
    loading = true;
    final prior = state.valueOrNull;
    try {
      var data = await cloud!.call('readCampusBoard', {
        'period': period,
        if (more) 'after': prior?.next,
        if (more) 'generation': prior?.generation,
      });
      if (data['status'] == 'refresh') {
        data = await cloud!.call('readCampusBoard', {'period': period});
        more = false;
      }
      if (!mounted) return;
      if (more && prior != null) {
        final rows = {
          for (final entry in prior.entries) entry.uid: entry.toJson(),
        };
        for (final row in data['entries'] as List? ?? []) {
          rows[row['uid']] = Map<String, dynamic>.from(row);
        }
        data['entries'] = rows.values.toList();
      }
      state = AsyncData(decode(data));
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      if (!mounted) return;
      try {
        final cached = prefs.getString(key);
        state = AsyncData(
          cached == null
              ? const CampusBoard(
                  'Rankings are unavailable. Your local study history is safe.',
                  [],
                  null,
                  null,
                )
              : decode(
                  Map<String, dynamic>.from(jsonDecode(cached)),
                  cached: true,
                ),
        );
      } catch (_) {
        state = const AsyncData(
          CampusBoard('No cached rankings available.', [], null, null),
        );
      }
    } finally {
      loading = false;
    }
  }

  Future<void> privacy(String alias, bool optOut) async {
    if (cloud == null) throw StateError('Campus backend is not connected.');
    await cloud!.call('setRankPrivacy', {'alias': alias, 'optOut': optOut});
    await prefs.remove(key);
    await load();
  }

  @override
  void dispose() {
    cloud?.dispose();
    super.dispose();
  }
}

final campusBoardProvider = StateNotifierProvider.autoDispose
    .family<CampusController, AsyncValue<CampusBoard>, String>((ref, period) {
      final user = ref.watch(authStateProvider).valueOrNull;
      final ready =
          ref.watch(firebaseReadyProvider) &&
          studyApiBase.isNotEmpty &&
          user != null;
      return CampusController(
        ready ? StudyCloud(user) : null,
        ref.watch(sharedPrefsProvider),
        'hyzen_campus_${user?.uid ?? 'guest'}_$period',
        period,
      );
    });

class CampusRankScreen extends ConsumerStatefulWidget {
  const CampusRankScreen({super.key});
  @override
  ConsumerState<CampusRankScreen> createState() => _CampusRankScreenState();
}

class _CampusRankScreenState extends ConsumerState<CampusRankScreen> {
  var period = 'week';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(campusBoardProvider(period).notifier).load());
      }
    });
  }

  Future<void> _privacy() async {
    final alias = TextEditingController(
      text:
          ref.read(campusBoardProvider(period)).valueOrNull?.mine?.name ??
          'Student',
    );
    var optOut = true;
    String? error;
    var saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, update) => AlertDialog(
            title: const Text('Ranking privacy'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Verified students from all colleges join their professional year. Your alias is shown to other participants.',
                  ),
                  TextField(
                    controller: alias,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Display alias',
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Hide me from ranking'),
                    value: optOut,
                    onChanged: saving ? null : (v) => update(() => optOut = v),
                  ),
                  if (error != null) Text(error!),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (alias.text.trim().isEmpty) {
                          update(() => error = 'Enter an alias.');
                          return;
                        }
                        update(() => saving = true);
                        try {
                          await ref
                              .read(campusBoardProvider(period).notifier)
                              .privacy(alias.text.trim(), optOut);
                          if (dialog.mounted) Navigator.pop(dialog);
                        } catch (_) {
                          if (dialog.mounted) {
                            update(() {
                              saving = false;
                              error =
                                  'Ranking service is unavailable. No privacy change was saved.';
                            });
                          }
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      alias.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : _navy;
    final bg = dark ? Colors.black : const Color(0xFFEAF3FF);
    final surface = dark ? const Color(0xFF1B1C20) : Colors.white;
    final board = ref.watch(campusBoardProvider(period));
    final verifiedYear = board.valueOrNull?.academicYear;
    Widget panel(Widget content) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? Colors.white12 : const Color(0xFFD3E2F3),
        ),
      ),
      child: content,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        toolbarHeight: 80 * scale,
        backgroundColor: bg,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              scale > 1.4 ? 'Ranks' : 'Prof. Rank',
              semanticsLabel: 'Professional Rank',
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            Text(
              'All colleges',
              style: TextStyle(color: ink.withValues(alpha: .67), fontSize: 11),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ink),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          IconButton(
            tooltip: 'Ranking privacy',
            onPressed: _privacy,
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: ink),
            onPressed: () => _showRules(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(campusBoardProvider(period).notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
          children: [
            Container(
              height: 135 + 50 * (scale - 1),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      HomeTimePhase.at(DateTime.now()).asset,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xC7F0F6FF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Material(
                        color: const Color(0xEDFFFFFF),
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school_outlined, color: _blue),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  verifiedYear == null
                                      ? 'By professional\nAll colleges'
                                      : 'Professional $verifiedYear\nAll colleges',
                                  maxLines: 4,
                                  style: const TextStyle(
                                    color: _navy,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: 'week',
                  tooltip: 'This Week',
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Week', maxLines: 1),
                  ),
                ),
                ButtonSegment(
                  value: 'month',
                  tooltip: 'This Month',
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Month', maxLines: 1),
                  ),
                ),
                ButtonSegment(
                  value: 'semester',
                  tooltip: 'Professional Total',
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Total', maxLines: 1),
                  ),
                ),
              ],
              selected: {period},
              showSelectedIcon: false,
              onSelectionChanged: (values) =>
                  setState(() => period = values.first),
            ),
            const SizedBox(height: 16),
            board.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(35),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) =>
                  panel(Text('Could not load verified rankings: $e')),
              data: (data) => Column(
                children: [
                  if (data.next != null)
                    TextButton(
                      onPressed: () => ref
                          .read(campusBoardProvider(period).notifier)
                          .load(more: true),
                      child: const Text('Load more learners'),
                    ),
                  panel(
                    Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_circle, color: _blue),
                            const SizedBox(width: 7),
                            Text(
                              'Your Rank',
                              style: TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (data.mine == null)
                          Text(
                            data.status == 'ready'
                                ? 'Not ranked this period'
                                : data.status,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ink),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _RankStat(
                                '#${data.mine!.rank}',
                                'Your rank',
                                ink,
                              ),
                              _RankStat(
                                '${data.mine!.minutes ~/ 60}h ${data.mine!.minutes % 60}m',
                                'Verified study',
                                ink,
                              ),
                              _RankStat('${data.mine!.points}', 'Points', ink),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_outlined,
                              color: Color(0xFFE3B52A),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Leaderboard',
                                style: TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh_rounded, color: ink),
                              onPressed: () =>
                                  ref.invalidate(campusBoardProvider(period)),
                            ),
                          ],
                        ),
                        if (data.updatedAt != null)
                          Text(
                            '${data.cached ? 'Last synced (offline)' : 'Last verified update'}: ${data.updatedAt!.toLocal()}',
                            style: TextStyle(
                              color: ink.withValues(alpha: .55),
                              fontSize: 10,
                            ),
                          ),
                        if (data.entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              data.status,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ink.withValues(alpha: .7),
                              ),
                            ),
                          )
                        else
                          for (final entry in data.entries)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _RankRow(
                                entry: entry,
                                highlight:
                                    entry.uid ==
                                    ref
                                        .read(authStateProvider)
                                        .valueOrNull
                                        ?.uid,
                                ink: ink,
                                dark: dark,
                              ),
                            ),
                        if (data.mine != null &&
                            !data.entries.any((e) => e.uid == data.mine!.uid))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _RankRow(
                              entry: data.mine!,
                              highlight: true,
                              ink: ink,
                              dark: dark,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            panel(
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bar_chart_rounded, color: _blue),
                title: Text(
                  'How Professional Rank Works?',
                  style: TextStyle(fontWeight: FontWeight.w800, color: ink),
                ),
                subtitle: Text(
                  'Only verified active study and eligible students count.',
                  style: TextStyle(
                    fontSize: 11,
                    color: ink.withValues(alpha: .6),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showRules(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRules(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('How Professional Rank Works'),
      content: const SingleChildScrollView(
        child: Text(
          'All colleges compete together within each verified professional year (1–5). Weekly, monthly and Professional Total scores stay separate.\n\n'
          'Scoring: 1 point per verified minute (max 360 minutes per day), '
          '+2 points per valid 10-minute session (max 5 sessions per day), '
          'and +5 for each consecutive qualifying day after the first.\n\n'
          'An administrator verifies your professional year and you can opt out. Only server-timed active sessions earn points; offline personal history does not. '
          'Periods use Pakistan time. No ranking is shown without verified data.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _RankStat extends StatelessWidget {
  const _RankStat(this.value, this.label, this.ink);
  final String value, label;
  final Color ink;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 17),
      ),
      Text(
        label,
        style: TextStyle(color: ink.withValues(alpha: .6), fontSize: 10),
      ),
    ],
  );
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.highlight,
    required this.ink,
    required this.dark,
  });
  final CampusEntry entry;
  final bool highlight, dark;
  final Color ink;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: highlight
          ? (dark ? const Color(0xFF13355C) : const Color(0xFFD1E7FF))
          : (dark ? Colors.white10 : const Color(0xFFF4F7FE)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 25,
          child: Text(
            '#${entry.rank}',
            style: TextStyle(color: ink, fontWeight: FontWeight.w900),
          ),
        ),
        const CircleAvatar(
          radius: 18,
          child: Icon(Icons.person_outline, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: TextStyle(color: ink, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Year ${entry.year}',
                style: TextStyle(
                  color: ink.withValues(alpha: .6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${entry.minutes ~/ 60}h ${entry.minutes % 60}m',
          style: TextStyle(color: ink, fontSize: 11),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            '${entry.points} pts',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

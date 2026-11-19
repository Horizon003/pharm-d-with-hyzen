import 'reward_controller.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_cloud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/widgets/refinement_art.dart';

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
    this.setupRequired = false,
    this.verificationRequired = false,
    this.optOut = true,
    this.alias,
    this.statusCode = 'ready',
  });
  final String status;
  final bool setupRequired, verificationRequired, optOut;
  final String? alias;
  final String statusCode;
  final List<CampusEntry> entries;
  final CampusEntry? mine;
  final DateTime? updatedAt;
  final int? next;
  final String? generation;
  final bool cached;
  final int? academicYear;
}

class CampusController extends StateNotifier<AsyncValue<CampusBoard>>
    with WidgetsBindingObserver {
  CampusController(this.cloud, this.prefs, this.key, this.period)
    : super(const AsyncLoading()) {
    if (cloud == null) {
      state = const AsyncData(
        CampusBoard('Sign in to see your study league.', [], null, null),
      );
    } else {
      WidgetsBinding.instance.addObserver(this);
      _timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_foreground) unawaited(load());
      });
      if (cloud?.supportsRealtime == true) {
        _live = cloud!.watch('rank:$period').listen((_) {
          if (_foreground) unawaited(load());
        }, onError: (Object _) {});
      }
      unawaited(load());
    }
  }
  final StudyCloud? cloud;
  final SharedPreferences prefs;
  final String key, period;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _live;
  bool _foreground = true;
  bool loading = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(load());
  }

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
        setupRequired: data['setupRequired'] == true,
        verificationRequired: data['verificationRequired'] == true,
        optOut: data['optOut'] != false,
        alias: data['alias'] as String?,
        statusCode: data['statusCode'] as String? ?? 'ready',
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
                  'Check your connection and refresh. Your saved study history is safe.',
                  [],
                  null,
                  null,
                  statusCode: 'offline',
                )
              : decode(
                  Map<String, dynamic>.from(jsonDecode(cached)),
                  cached: true,
                ),
        );
      } catch (_) {
        state = const AsyncData(
          CampusBoard(
            'Check your connection and refresh.',
            [],
            null,
            null,
            statusCode: 'offline',
          ),
        );
      }
    } finally {
      loading = false;
    }
  }

  Future<void> privacy(String alias, bool optOut, {int? academicYear}) async {
    if (cloud == null) {
      throw StateError('Sign in to save your ranking preferences.');
    }
    await cloud!.call('setRankPrivacy', {
      'alias': alias,
      'optOut': optOut,
      if (academicYear != null) 'academicYear': academicYear,
    });
    await prefs.remove(key);
    await load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _live?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
      final controller = CampusController(
        ready ? StudyCloud(user) : null,
        ref.watch(sharedPrefsProvider),
        'hyzen_campus_${user?.uid ?? 'guest'}_$period',
        period,
      );
      ref.listen(rankRefreshProvider, (_, __) {
        unawaited(controller.load());
      });
      return controller;
    });

class CampusRankScreen extends ConsumerStatefulWidget {
  const CampusRankScreen({super.key});
  @override
  ConsumerState<CampusRankScreen> createState() => _CampusRankScreenState();
}

class _CampusRankScreenState extends ConsumerState<CampusRankScreen> {
  var period = 'week';
  bool _prompted = false, _dialogOpen = false;

  Future<void> _privacy() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final data = ref.read(campusBoardProvider(period)).valueOrNull;
    final profile = ref.read(profileProvider).valueOrNull;
    var name =
        (data?.alias ??
        profile?.fullName ??
        ref.read(authStateProvider).valueOrNull?.displayName ??
        '');
    bool? visible = data?.setupRequired == false
        ? !(data?.optOut ?? true)
        : null;
    int? year = data?.verificationRequired == true
        ? profile?.professionalYear ?? data?.academicYear
        : data?.academicYear ?? profile?.professionalYear;
    String? error;
    var saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, update) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RefinementArt(RefinementGlyph.rank, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      data?.setupRequired == true
                          ? 'Make your place in the league'
                          : 'Your ranking profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the name other learners see. You decide whether your profile appears on the leaderboard.',
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      initialValue: name,
                      maxLength: 40,
                      style: const TextStyle(fontSize: 16),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'Your name or nickname',
                        counterText: '',
                      ),
                      onChanged: (value) => update(() => name = value),
                    ),
                    if (profile?.professionalYear == null &&
                        data?.academicYear == null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: year,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Professional year',
                        ),
                        items: [
                          for (var y = 1; y <= 5; y++)
                            DropdownMenuItem(value: y, child: Text('Year $y')),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => update(() => year = v),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Profile visibility',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Show my rank'),
                          selected: visible == true,
                          onSelected: saving
                              ? null
                              : (_) => update(() => visible = true),
                        ),
                        ChoiceChip(
                          label: const Text('Keep it private'),
                          selected: visible == false,
                          onSelected: saving
                              ? null
                              : (_) => update(() => visible = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your email, phone number and documents stay private.',
                      style: TextStyle(fontSize: 12),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.pop(dialog),
                          child: const Text('Not now'),
                        ),
                        FilledButton(
                          onPressed:
                              saving ||
                                  name.trim().isEmpty ||
                                  visible == null ||
                                  year == null
                              ? null
                              : () async {
                                  update(() => saving = true);
                                  try {
                                    await ref
                                        .read(
                                          campusBoardProvider(period).notifier,
                                        )
                                        .privacy(
                                          name.trim(),
                                          !visible!,
                                          academicYear: year,
                                        );
                                    if (dialog.mounted) Navigator.pop(dialog);
                                  } catch (e) {
                                    if (dialog.mounted) {
                                      update(() {
                                        saving = false;
                                        error = e is StateError
                                            ? e.message
                                            : 'Could not save just now. Check your connection and try again.';
                                      });
                                    }
                                  }
                                },
                          child: Text(saving ? 'Saving…' : 'Confirm choices'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(campusBoardProvider(period));
    final board = state.valueOrNull;
    if (!_prompted && board?.setupRequired == true) {
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_privacy());
      });
    }
    final theme = Theme.of(context);
    final name =
        board?.alias ??
        ref.watch(profileProvider).valueOrNull?.fullName ??
        'Your progress';
    Widget card(Widget child, {Color? color}) => HCard(
      radius: 24,
      color: color,
      shadow: false,
      padding: const EdgeInsets.all(16),
      child: child,
    );
    return HBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: HTopBar(
          title: 'Professional rank',
          actions: [
            IconButton(
              tooltip: 'Ranking privacy',
              onPressed: _privacy,
              icon: const Icon(Icons.tune_rounded, size: 20),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () =>
              ref.read(campusBoardProvider(period).notifier).load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              HCard(
                radius: 28,
                shadow: false,
                gradient: const LinearGradient(
                  colors: [Color(0xffffdfb7), Color(0xfff2e7fc)],
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            board?.academicYear == null
                                ? 'Your study league'
                                : 'Professional year ${board!.academicYear}',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            board?.mine == null
                                ? 'Small sessions.\nSteady progress.'
                                : '#${board!.mine!.rank}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            board?.mine == null
                                ? 'Build your place, one focused day at a time.'
                                : name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const RefinementArt(RefinementGlyph.rank, size: 86),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('Week')),
                  ButtonSegment(value: 'month', label: Text('Month')),
                  ButtonSegment(value: 'semester', label: Text('All time')),
                ],
                selected: {period},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => period = v.first),
              ),
              const SizedBox(height: 16),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (board != null) ...[
                if (board.statusCode != 'ready') ...[
                  card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          board.statusCode == 'offline'
                              ? 'Let’s reconnect'
                              : board.setupRequired
                              ? 'Let’s set up your profile'
                              : board.verificationRequired
                              ? 'Your year is under review'
                              : 'You’re studying privately',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          board.statusCode == 'offline'
                              ? board.status
                              : board.setupRequired
                              ? 'A display name and visibility choice are all you need to get started.'
                              : board.verificationRequired
                              ? 'Your choices are saved. We’ll review your professional year before your score appears here. Your personal study progress continues.'
                              : 'Your name and score are hidden. You can change this whenever you like.',
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: board.statusCode == 'offline'
                              ? () => ref
                                    .read(campusBoardProvider(period).notifier)
                                    .load()
                              : _privacy,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: Text(
                            board.statusCode == 'offline'
                                ? 'Try again'
                                : board.setupRequired
                                ? 'Set up ranking'
                                : 'Edit my choices',
                          ),
                        ),
                      ],
                    ),
                    color: const Color(0xfff1edf8),
                  ),
                  const SizedBox(height: 14),
                ],
                if (board.mine != null) ...[
                  card(
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _RankFigure(
                          '${board.mine!.minutes ~/ 60}h ${board.mine!.minutes % 60}m',
                          'Study time',
                        ),
                        _RankFigure('${board.mine!.points}', 'Rank points'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your year, together',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh ranking',
                      onPressed: () =>
                          ref.read(campusBoardProvider(period).notifier).load(),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ],
                ),
                if (board.cached)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Offline · showing your last update',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (board.entries.isEmpty)
                  card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RefinementArt(RefinementGlyph.subject, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          board.statusCode == 'ready'
                              ? 'The next session counts'
                              : 'A place for your progress',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          board.statusCode == 'ready'
                              ? 'Open a study resource to start building your score. Rankings update as study time is confirmed.'
                              : 'Your leaderboard will appear here when your profile is ready.',
                        ),
                      ],
                    ),
                  )
                else
                  for (final entry in board.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: card(
                        Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${entry.rank}'.padLeft(2, '0'),
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.name,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${entry.minutes} min focused',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${entry.points}',
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                        color:
                            entry.uid ==
                                ref.read(authStateProvider).valueOrNull?.uid
                            ? const Color(0xffffedda)
                            : null,
                      ),
                    ),
                if (board.next != null)
                  TextButton(
                    onPressed: () => ref
                        .read(campusBoardProvider(period).notifier)
                        .load(more: true),
                    child: const Text('More learners'),
                  ),
              ],
              const SizedBox(height: 16),
              card(
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('How your score grows'),
                  children: const [
                    Text(
                      'One rank point per study minute, up to 360 a day. Completed 10-minute sessions and consistent study days earn bonuses. Week and month totals follow Pakistan time. Your year is checked before you join the public leaderboard.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankFigure extends StatelessWidget {
  const _RankFigure(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

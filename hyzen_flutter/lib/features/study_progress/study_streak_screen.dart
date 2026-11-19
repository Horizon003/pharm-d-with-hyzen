import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/widgets/polish_ui.dart';
import '../../core/widgets/reward_art.dart';
import '../../core/widgets/surfaces.dart';
import 'reward_controller.dart';
import 'study_tracker.dart';
import 'campus_rank_screen.dart';

class StudyStreakScreen extends ConsumerWidget {
  const StudyStreakScreen({super.key});
  Future<void> _claim(
    BuildContext context,
    WidgetRef ref, {
    int? milestone,
  }) async {
    final reward = ref.read(rewardProvider);
    final success = await reward.claim(milestone: milestone);
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reward.error ?? 'Please try again.')),
      );
      return;
    }
    final index = milestone == null
        ? 2
        : 10 + rewardMilestones.indexOf(milestone);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        content: TweenAnimationBuilder<double>(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(c) ? 0 : 420,
          ),
          tween: Tween(begin: .8, end: 1),
          curve: Curves.easeOutCubic,
          builder: (c, v, _) => CustomPaint(
            painter: _Celebration(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(scale: v, child: RewardArt(index, size: 128)),
                const SizedBox(height: 12),
                Text(
                  milestone == null
                      ? 'Today is yours!'
                      : '$milestone-day achievement',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  milestone == null
                      ? '+100 daily points · ${reward.streak} day streak'
                      : '+50 points · badge unlocked',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Lovely'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rewardProvider),
        study = ref.watch(studyTrackerProvider);
    final rank = ref.watch(campusBoardProvider('week')).valueOrNull?.mine;
    final today = DateTime.parse(r.today);
    final first = r.days.isEmpty ? today : DateTime.parse(r.days.first);
    final elapsed = today.difference(first).inDays;
    final start = first.add(
      Duration(days: (elapsed < 0 ? 0 : elapsed ~/ 30) * 30),
    );
    Widget panel(Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
    return HBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Your daily streak'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: r.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xffffe2d0), Color(0xfff3d9ea)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, c) => Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'A little every day.',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                height: 1.08,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Claim your daily streak.\nSmall steps add up.',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      HSoftArt(
                        loop: true,
                        enabled: ref.watch(
                          boolPrefProvider('pref_ambient_motion'),
                        ),
                        child: RewardArt(2, size: c.maxWidth < 300 ? 100 : 136),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${r.streak} day streak')),
                  Chip(label: Text('My Points · ${r.points}')),
                  ActionChip(
                    onPressed: () => context.push('/campus-rank'),
                    label: Text(
                      'My Rank · ${rank == null ? 'View' : '#${rank.rank}'}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your next 30 days',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '100 points a day. An extra 200 every full week.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c) {
                        final columns =
                            MediaQuery.textScalerOf(context).scale(1) > 1.35
                            ? 4
                            : 7;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 30,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent:
                                    MediaQuery.textScalerOf(context).scale(32) +
                                    46,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 8,
                              ),
                          itemBuilder: (context, i) {
                            final date = start.add(Duration(days: i)),
                                key = studyDayKey(date),
                                claimed = r.days.contains(key),
                                isToday = key == r.today;
                            return Semantics(
                              label:
                                  '${date.day}/${date.month}, ${claimed
                                      ? 'claimed'
                                      : isToday
                                      ? 'today'
                                      : 'not claimed'}',
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? const Color(0xffffeee3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isToday
                                      ? Border.all(
                                          color: const Color(0xffcc9274),
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    RewardArt(
                                      3 + i % 7,
                                      size: 32,
                                      claimed: claimed,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        'Mo',
                                        'Tu',
                                        'We',
                                        'Th',
                                        'Fr',
                                        'Sa',
                                        'Su',
                                      ][date.weekday - 1],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${date.day}/${date.month}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                child: FilledButton.icon(
                  key: const ValueKey('claim-daily-points'),
                  onPressed: r.busy || r.claimedToday
                      ? null
                      : () => _claim(context, ref),
                  icon: const RewardArt(3, size: 24),
                  label: Text(
                    r.claimedToday
                        ? 'Today’s points claimed'
                        : r.busy
                        ? 'Confirming…'
                        : 'Claim Daily Points',
                  ),
                ),
              ),
              if (r.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(r.error!, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 16),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Achievements',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Claim a badge and 50 extra points at each milestone.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, c) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < rewardMilestones.length; i++)
                            SizedBox(
                              width: (c.maxWidth - 16) / 3,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: r.busy
                                    ? null
                                    : () =>
                                          r.badges.contains(
                                                rewardMilestones[i],
                                              ) ||
                                              r.best < rewardMilestones[i]
                                          ? ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  r.badges.contains(
                                                        rewardMilestones[i],
                                                      )
                                                      ? 'Badge already claimed'
                                                      : 'Claim ${rewardMilestones[i]} consecutive days to unlock',
                                                ),
                                              ),
                                            )
                                          : _claim(
                                              context,
                                              ref,
                                              milestone: rewardMilestones[i],
                                            ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      Opacity(
                                        opacity: r.best >= rewardMilestones[i]
                                            ? 1
                                            : .4,
                                        child: RewardArt(10 + i, size: 56),
                                      ),
                                      Text(
                                        '${rewardMilestones[i]} days',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        [
                                          'Bronze',
                                          'Gold',
                                          'Diamond',
                                          'Ruby',
                                          'Ultimate',
                                          'Mythic',
                                        ][i],
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      Text(
                                        r.badges.contains(rewardMilestones[i])
                                            ? 'Claimed'
                                            : r.best >= rewardMilestones[i]
                                            ? 'Claim +50'
                                            : 'Locked',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent breaks',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (r.days.isEmpty)
                      const Text('Your first streak starts with today’s claim.')
                    else
                      ..._breaks(r.days).map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(s),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '${study.highestStreak} days is your best study streak (15+ active minutes/day).',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
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

  List<String> _breaks(List<String> days) {
    final out = <String>[];
    for (var i = days.length - 1; i > 0 && out.length < 3; i--) {
      final a = DateTime.parse(days[i - 1]), b = DateTime.parse(days[i]);
      if (b.difference(a).inDays > 1) {
        out.add(
          'Break after ${a.day}/${a.month} · resumed ${b.day}/${b.month}',
        );
      }
    }
    return out.isEmpty ? ['No breaks between claimed days.'] : out;
  }
}

class _Celebration extends CustomPainter {
  _Celebration(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 20; i++) {
      final angle = i * math.pi * .77, radius = 30 + value * size.width * .38;
      final p = Offset(
        size.width / 2 + math.cos(angle) * radius,
        size.height * .38 + math.sin(angle) * radius * .8,
      );
      canvas.drawCircle(
        p,
        2.5,
        Paint()
          ..color = [
            const Color(0xffe2b65d),
            const Color(0xffac8ac6),
            const Color(0xff84af95),
          ][i % 3].withValues(alpha: .7),
      );
    }
  }

  @override
  bool shouldRepaint(_Celebration old) => old.value != value;
}

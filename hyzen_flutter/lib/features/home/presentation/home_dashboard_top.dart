import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/polish_ui.dart';
import '../../../core/widgets/reward_art.dart';
import '../../study_progress/study_tracker.dart';
import '../../study_progress/reward_controller.dart';
import '../../study_progress/study_calendar.dart';
import 'home_screen.dart' show homeClockProvider;

class HomeDashboardTop extends ConsumerWidget {
  const HomeDashboardTop({super.key, required this.year});
  final int? year;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(studyTrackerProvider),
        r = ref.watch(rewardProvider),
        t = Theme.of(context);
    final percent = (p.todaySeconds / (p.dailyGoal * 60)).clamp(0.0, 1.0);
    final date = DateTime.parse(r.today),
        monday = date.subtract(Duration(days: date.weekday - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          key: const ValueKey('home-focus-card'),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          color: const Color(0xffe4d9f4),
          child: InkWell(
            onTap: () => context.push('/study-progress'),
            child: Ink(
              decoration: const BoxDecoration(gradient: hFocusGradient),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, c) => Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily challenge',
                                style: t.textTheme.headlineMedium?.copyWith(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                  letterSpacing: -.7,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Study Time · ${formatStudyTime(p.todaySeconds)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
                          HSoftArt(
                            loop: true,
                            enabled: ref.watch(
                              boolPrefProvider('pref_ambient_motion'),
                            ),
                            child: Image.asset(
                              'assets/reference/focus-shapes.png',
                              key: const ValueKey('home-hero-art'),
                              width: c.maxWidth * .28,
                              height: 96,
                              fit: BoxFit.contain,
                              cacheWidth: 360,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: percent,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => context.push('/study-streak'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const RewardArt(3, size: 24),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Streak · ${r.streak} ${r.streak == 1 ? 'day' : 'days'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Semantics(
                            label:
                                'Day ${i + 1}, ${r.days.contains(studyDayKey(monday.add(Duration(days: i)))) ? 'claimed' : 'not claimed'}',
                            child: InkWell(
                              onTap: () => context.push('/study-streak'),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Column(
                                  children: [
                                    RewardArt(
                                      3 + i,
                                      size: 26,
                                      claimed: r.days.contains(
                                        studyDayKey(
                                          monday.add(Duration(days: i)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Day ${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
          ),
        ),
        if (!r.claimedToday) ...[
          const SizedBox(height: 8),
          Align(
            child: HSoftArt(
              loop: true,
              enabled: ref.watch(boolPrefProvider('pref_ambient_motion')),
              child: FilledButton.icon(
                key: const ValueKey('home-claim-streak'),
                onPressed: () => context.push('/study-streak'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xfff4cbb5),
                  foregroundColor: HColors.ink,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const RewardArt(3, size: 22),
                label: const Text(
                  'Claim Daily Streak',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        StudyWeekRibbon(
          now: ref.watch(homeClockProvider)(),
          days: p.days,
          events: ref.watch(calendarProvider).events,
        ),
      ],
    );
  }
}

class StudyWeekRibbon extends StatelessWidget {
  const StudyWeekRibbon({
    super.key,
    required this.now,
    required this.days,
    this.events = const [],
  });
  final List<PlannerEvent> events;
  final DateTime now;
  final Map<String, int> days;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Builder(
              builder: (context) {
                final date = monday.add(Duration(days: i)),
                    today = i + 1 == now.weekday,
                    dayEvents = events
                        .where((e) => e.day == calendarDay(date))
                        .toList();
                final color = dayEvents.isNotEmpty
                    ? Color(dayEvents.first.color)
                    : today
                    ? HColors.ink
                    : Colors.white.withValues(alpha: .6);
                final ink = color.computeLuminance() < .4
                    ? Colors.white
                    : HColors.ink;
                final recorded = (days[studyDayKey(date)] ?? 0) >= 900;
                return Semantics(
                  label:
                      '${date.day}/${date.month}, ${dayEvents.length} events. Open calendar',
                  button: true,
                  child: InkWell(
                    onTap: () => context.push(
                      '/study-calendar?date=${calendarDay(date)}',
                    ),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: today ? HColors.ink : HColors.outlineStrong,
                          width: today ? 1.5 : .8,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: today || recorded
                                  ? ink
                                  : Colors.transparent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (MediaQuery.textScalerOf(context).scale(1) > 1.3
                                ? ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                                : [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun',
                                  ])[i],
                            maxLines: 1,
                            style: t.textTheme.labelSmall?.copyWith(
                              color: ink,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${date.day}',
                              style: t.textTheme.titleMedium?.copyWith(
                                color: ink,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (dayEvents.length > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final e in dayEvents.take(3))
                                  Padding(
                                    padding: const EdgeInsets.all(1),
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Color(e.color),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: ink,
                                          width: .5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

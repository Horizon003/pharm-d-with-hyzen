import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'study_tracker.dart';
import '../home/presentation/home_time_artwork.dart';

const _deep = Color(0xFF071632);
const _azure = Color(0xFF1D65AE);

/// Study-streak detail reconstructed from the uploaded UI references.
/// Every count, day and milestone derives from locally recorded focus time.
class StudyStreakScreen extends ConsumerStatefulWidget {
  const StudyStreakScreen({super.key});
  @override
  ConsumerState<StudyStreakScreen> createState() => _StudyStreakScreenState();
}

class _StudyStreakScreenState extends ConsumerState<StudyStreakScreen> {
  int historyRange = 7;

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(studyTrackerProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? Colors.black : const Color(0xFFEAF2FF);
    final card = dark ? const Color(0xFF181B20) : Colors.white;
    final ink = dark ? Colors.white : _deep;
    final subtle = dark ? Colors.white60 : const Color(0xFF576983);
    final now = DateTime.now();
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final week = [
      for (var i = 0; i < 7; i++)
        i >= now.weekday ? 0 : p.days[studyDayKey(monday.add(Duration(days: i)))] ?? 0,
    ];
    final weekCount = week.where((n) => n >= 900).length;
    final totalDays = p.days.entries.where((e) => e.value >= 900 && e.key.compareTo(studyDayKey(now)) <= 0).length;
    final totals = [
      for (var i = historyRange - 1; i >= 0; i--)
        p.days[studyDayKey(today.subtract(Duration(days: i)))] ?? 0,
    ];
    final maximum = totals.fold<int>(1, (a, b) => b > a ? b : a);

    Widget section(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0xFF30343C) : const Color(0xFFCEDCF0),
        ),
      ),
      child: child,
    );
    Widget sectionTitle(
      String text,
      IconData icon, {
      String? trailing,
      VoidCallback? onTap,
    }) => Row(
      children: [
        Icon(icon, size: 22, color: _azure),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        if (trailing != null)
          TextButton(
            onPressed: onTap,
            child: Text(
              trailing,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _azure,
              ),
            ),
          ),
      ],
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
              'Study Streak',
              style: TextStyle(color: ink, fontWeight: FontWeight.w900),
            ),
            Text(
              'Stay consistent and build your study habit',
              style: TextStyle(fontSize: 11, color: subtle),
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
            icon: Icon(Icons.info_outline_rounded, color: ink),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('How streaks work'),
                content: const Text(
                  'A study day counts when you complete at least 15 minutes of actively tracked focus time. Passive background time does not count.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Got it'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(25)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    HomeTimePhase.at(now).asset,
                    fit: BoxFit.cover,
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xD30D3560), Color(0x250A2448)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.currentStreak} Days',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                        ),
                      ),
                      const Text(
                        'Current Study Streak',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => context.push('/study-progress'),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                        ),
                        label: const Text('Keep it going!'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xE8D6ECFF),
                          foregroundColor: _deep,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          section(
            Column(
              children: [
                sectionTitle(
                  'This Week’s Streak',
                  Icons.calendar_month_outlined,
                  trailing: '$weekCount / 7 Days',
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 38,
                              height: 40,
                              decoration: BoxDecoration(
                                color: week[i] >= 900
                                    ? const Color(0xFFCDEBFF)
                                    : (dark
                                          ? Colors.white10
                                          : const Color(0xFFE7EAF0)),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                week[i] >= 900
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: week[i] >= 900 ? _azure : subtle,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              const [
                                'Mon',
                                'Tue',
                                'Wed',
                                'Thu',
                                'Fri',
                                'Sat',
                                'Sun',
                              ][i],
                              style: TextStyle(fontSize: 10, color: ink),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StreakMetric(
                  'Highest Streak',
                  '${p.highestStreak} Days',
                  Icons.emoji_events_rounded,
                  card,
                  ink,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _StreakMetric(
                  'Total Study Days',
                  '$totalDays Days',
                  Icons.calendar_month_outlined,
                  card,
                  ink,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _StreakMetric(
                  'Current Streak',
                  '${p.currentStreak} Days',
                  Icons.bolt_rounded,
                  card,
                  ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          section(
            Column(
              children: [
                sectionTitle(
                  'Recent Breaks',
                  Icons.history_rounded,
                  trailing: 'See All',
                  onTap: () => _showAllBreaks(p),
                ),
                if (p.recentBreaks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No breaks between recorded study days yet.',
                      style: TextStyle(color: subtle),
                    ),
                  ),
                for (final entry in p.recentBreaks.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: dark ? Colors.white10 : const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_busy_outlined, color: _azure),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry,
                              style: TextStyle(color: ink, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          section(
            Column(
              children: [
                sectionTitle('Streak History', Icons.bar_chart_rounded),
                Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButton<int>(
                    value: historyRange,
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
                      DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
                    ],
                    onChanged: (v) => setState(() => historyRange = v ?? 7),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: historyRange == 30
                        ? 900
                        : MediaQuery.sizeOf(context).width - 65,
                    height: 135 * scale,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < historyRange; i++)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  totals[i] == 0 ? '—' : '${totals[i] ~/ 60}m',
                                  style: TextStyle(fontSize: 9, color: subtle),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 10 + 85 * totals[i] / maximum,
                                  width: historyRange == 7 ? 37 : 15,
                                  decoration: BoxDecoration(
                                    color: totals[i] == 0
                                        ? const Color(0xFFB9C7D9)
                                        : _azure,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  historyRange == 7
                                      ? const [
                                          'Mon',
                                          'Tue',
                                          'Wed',
                                          'Thu',
                                          'Fri',
                                          'Sat',
                                          'Sun',
                                        ][(today.subtract(
                                              Duration(
                                                days: historyRange - i - 1,
                                              ),
                                            )).weekday -
                                            1]
                                      : '${today.subtract(Duration(days: historyRange - i - 1)).day}',
                                  style: TextStyle(fontSize: 9, color: ink),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          section(
            Column(
              children: [
                sectionTitle(
                  'Achievements',
                  Icons.workspace_premium_outlined,
                  trailing: 'See All',
                  onTap: () => _showAchievements(p.highestStreak),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    for (final milestone in [5, 7, 14, 30])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            constraints: BoxConstraints(minHeight: 115 * scale),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: p.highestStreak >= milestone
                                  ? (dark
                                        ? const Color(0xFF163B5F)
                                        : const Color(0xFFD4EDFF))
                                  : (dark
                                        ? Colors.white10
                                        : const Color(0xFFE6EBF3)),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  p.highestStreak >= milestone
                                      ? Icons.verified_rounded
                                      : Icons.lock_outline_rounded,
                                  color: p.highestStreak >= milestone
                                      ? _azure
                                      : subtle,
                                  size: 30,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$milestone-Day',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                                Text(
                                  p.highestStreak >= milestone
                                      ? 'Completed'
                                      : (p.currentStreak > 0 &&
                                                p.currentStreak < milestone
                                            ? 'In Progress'
                                            : 'Locked'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, color: subtle),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllBreaks(StudyTracker p) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text(
            'Recent Breaks',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
          const SizedBox(height: 15),
          if (p.recentBreaks.isEmpty) const Text('No recorded breaks yet.'),
          for (final line in p.recentBreaks)
            ListTile(leading: const Icon(Icons.event_busy), title: Text(line)),
        ],
      ),
    ),
  );

  Future<void> _showAchievements(int highest) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        shrinkWrap: true,
        children: [
          const Text(
            'Study Milestones',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          for (final milestone in [5, 7, 14, 30, 60, 100])
            ListTile(
              leading: Icon(
                highest >= milestone ? Icons.verified : Icons.lock_outline,
              ),
              title: Text('$milestone-Day Streak'),
              subtitle: Text(highest >= milestone ? 'Completed' : 'Locked'),
            ),
        ],
      ),
    ),
  );
}

class _StreakMetric extends StatelessWidget {
  const _StreakMetric(this.title, this.value, this.icon, this.color, this.ink);
  final String title, value;
  final IconData icon;
  final Color color, ink;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 96),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(19),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 23, color: _azure),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(color: ink, fontSize: 10),
        ),
      ],
    ),
  );
}
